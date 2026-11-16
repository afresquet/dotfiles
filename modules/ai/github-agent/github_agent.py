"""The GitHub agent: works on issues and PRs labelled `agent` in every repo
the GitHub App is installed on.

One long-running process, the launchd daemon, run as the `agent` user. It
takes the App's webhook deliveries (proxied here by Tailscale Funnel), queues
a job per issue/PR, and runs each job as two Claude Code sessions: a
coordinator that reads the thread and decides whether to ask, implement or
skip, and an implementer that makes the change in the item's worktree. Only
this process holds GitHub credentials: it fetches the thread, pushes, opens
the PR and comments. The agents get none.

The single argument is the JSON config the Nix module writes.
"""

import base64
import datetime
import hashlib
import hmac
import json
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CFG = json.loads(Path(sys.argv[1]).read_text())
API = "https://api.github.com"
LABEL = CFG["label"]
NEEDS_INFO = CFG["needsInfoLabel"]
# An issue's plan waits for this label before the agent implements it.
PLAN_APPROVED = CFG["planApprovedLabel"]
BRANCH_PREFIX = "agent/issue-"
# Comments from these can steer the agent; anyone else's are never shown to it.
TRUSTED_ASSOCIATIONS = {"OWNER", "MEMBER", "COLLABORATOR"}
# A trusted comment or the issue body can name the branch to start from
# (the dotfiles' failed flake update puts its candidate lock on one).
BASE_MARKER = re.compile(r"<!-- agent-base: ([\w./-]+) -->")
# Ends every comment the agent posts.
MARKER = "\n\n<!-- github-agent -->"
RUN_LINK = re.compile(r"github\.com/([\w.-]+/[\w.-]+)/actions/runs/(\d+)")


def log(msg):
    print(msg, file=sys.stderr, flush=True)


# ─── GitHub API ───


class NoRedirect(urllib.request.HTTPRedirectHandler):
    # Log downloads redirect to blob storage, which must not get the token.
    def redirect_request(self, *args, **kwargs):
        return None


OPENER = urllib.request.build_opener(NoRedirect)


def api(method, path, token, body=None, raw=False):
    url = path if path.startswith("https://") else API + path
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("X-GitHub-Api-Version", "2022-11-28")
    req.add_header("User-Agent", "github-agent")
    req.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with OPENER.open(req, timeout=60) as r:
            payload = r.read()
            link = r.headers.get("Link", "")
    except urllib.error.HTTPError as e:
        if e.code in (301, 302, 307) and raw:
            with urllib.request.urlopen(e.headers["Location"], timeout=60) as r:
                return r.read().decode("utf-8", "replace"), ""
        detail = e.read().decode("utf-8", "replace")[:500]
        raise RuntimeError(f"{method} {url}: {e.code} {detail}") from None
    if raw:
        return payload.decode("utf-8", "replace"), link
    return (json.loads(payload) if payload else None), link


def get(path, token):
    return api("GET", path, token)[0]


def get_all(path, token, key=None):
    """Every page of a list endpoint (or of `key` in an object endpoint)."""
    sep = "&" if "?" in path else "?"
    url, items = f"{path}{sep}per_page=100", []
    while url:
        page, link = api("GET", url, token)
        items += page[key] if key else page
        nxt = re.search(r'<([^>]+)>;\s*rel="next"', link)
        url = nxt.group(1) if nxt else None
    return items


def b64url(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def app_jwt():
    """The App authenticates as itself with a JWT signed by its private key."""
    now = int(time.time())
    claims = {"iat": now - 60, "exp": now + 540, "iss": str(CFG["appId"])}
    header = b64url(b'{"alg":"RS256","typ":"JWT"}')
    signing = f"{header}.{b64url(json.dumps(claims).encode())}"
    sig = subprocess.run(
        [CFG["openssl"], "dgst", "-sha256", "-sign", CFG["keyFile"]],
        input=signing.encode(), capture_output=True, check=True,
    ).stdout
    return f"{signing}.{b64url(sig)}"


class Tokens:
    """Installation tokens (an hour each), minted per installation, reused
    until ten minutes before they expire."""

    def __init__(self):
        self.lock = threading.Lock()
        self.cache = {}

    def get(self, installation):
        with self.lock:
            token, expires = self.cache.get(installation, (None, 0))
            if expires - time.time() > 600:
                return token
            r, _ = api("POST", f"/app/installations/{installation}/access_tokens", app_jwt())
            expires = datetime.datetime.fromisoformat(r["expires_at"].replace("Z", "+00:00")).timestamp()
            self.cache[installation] = (r["token"], expires)
            return r["token"]


TOKENS = Tokens()
BOT = {}


def bot(token):
    """The App's bot account: its login filters its own comments out, and its
    noreply address makes GitHub show its commits as the App's."""
    if not BOT:
        slug = get("/app", app_jwt())["slug"]
        login = f"{slug}[bot]"
        uid = get(f"/users/{urllib.parse.quote(login)}", token)["id"]
        BOT.update(login=login, name=login, email=f"{uid}+{login}@users.noreply.github.com")
    return BOT


def labels_of(obj):
    return {label["name"] for label in obj.get("labels", [])}


def comment(repo, number, token, body):
    api("POST", f"/repos/{repo}/issues/{number}/comments", token, {"body": body})


def feedback(repo, number, token, text, replies, thread):
    """Answers to inline review comments go in their threads (which notifies
    whoever wrote them); the rest, if anything, as one comment on the thread
    that mentions the person the agent answers to."""
    rest = []
    for r in replies or []:
        try:
            if r["comment_id"] not in thread.inline:
                raise RuntimeError("not an inline comment on this PR")
            api("POST", f"/repos/{repo}/pulls/{number}/comments/{r['comment_id']}/replies", token, {"body": r["body"] + MARKER})
        except RuntimeError as e:
            log(f"{repo}#{number}: reply to {r['comment_id']}: {e}")
            rest.append(r["body"])
    text = "\n\n".join(t for t in [text.strip(), *rest] if t)
    if text:
        comment(repo, number, token, thread.mention + text + MARKER)


def set_needs_info(repo, number, token, on):
    if on:
        api("POST", f"/repos/{repo}/issues/{number}/labels", token, {"labels": [NEEDS_INFO]})
        return
    try:
        api("DELETE", f"/repos/{repo}/issues/{number}/labels/{urllib.parse.quote(NEEDS_INFO)}", token)
    except RuntimeError:
        pass  # wasn't there


# ─── Git ───


def git(*args, cwd, token=None, check=True):
    """git with the token as an HTTP header for github.com, passed through the
    environment so it's neither on a command line nor in a config file."""
    env = {"HOME": CFG["home"], "PATH": CFG["path"], "GIT_TERMINAL_PROMPT": "0", "GIT_EDITOR": "true"}
    if token:
        basic = base64.b64encode(f"x-access-token:{token}".encode()).decode()
        env.update(
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="http.https://github.com/.extraheader",
            GIT_CONFIG_VALUE_0=f"AUTHORIZATION: basic {basic}",
        )
    r = subprocess.run([CFG["git"], *args], cwd=cwd, env=env, capture_output=True, text=True)
    if check and r.returncode:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()}")
    return r


def rev(ref, cwd):
    r = git("rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", cwd=cwd, check=False)
    return r.stdout.strip() or None


REPO_LOCKS = {}
REPO_LOCKS_LOCK = threading.Lock()


class Repo:
    """<reposDir>/<owner>/<name>/: `.bare` (the clone), `main` (a detached
    checkout kept at the default branch's tip, for reference) and one
    worktree per issue or PR the agent works on."""

    def __init__(self, full):
        self.full = full
        self.dir = Path(CFG["reposDir"]) / full
        self.bare = self.dir / ".bare"
        self.main = self.dir / "main"
        with REPO_LOCKS_LOCK:
            self.lock = REPO_LOCKS.setdefault(full, threading.Lock())

    def worktree(self, kind, number):
        return self.dir / f"{kind}-{number}"

    def sync(self, token, default_branch):
        """Clone if new, fetch, and move `main` to the default branch's tip.
        False if the repository has no commits yet. Call with self.lock held."""
        if not self.bare.exists():
            self.dir.mkdir(parents=True, exist_ok=True)
            git("clone", "--bare", "--quiet", f"https://github.com/{self.full}.git", str(self.bare), cwd=self.dir, token=token)
            # A bare clone maps branches straight to refs/heads; worktrees want
            # remote-tracking refs, and their reflog lets a rebase find the
            # fork point after a base branch is force-pushed.
            git("config", "remote.origin.fetch", "+refs/heads/*:refs/remotes/origin/*", cwd=self.bare)
            git("config", "core.logAllRefUpdates", "always", cwd=self.bare)
        identity = bot(token)
        git("config", "user.name", identity["name"], cwd=self.bare)
        git("config", "user.email", identity["email"], cwd=self.bare)
        git("fetch", "--quiet", "--prune", "origin", cwd=self.bare, token=token)
        if not rev(f"origin/{default_branch}", self.bare):
            return False  # an empty repository: nothing to check out yet
        if (self.main / ".git").exists():
            git("checkout", "--quiet", "--force", "--detach", f"origin/{default_branch}", cwd=self.main)
        else:
            git("worktree", "add", "--quiet", "--detach", str(self.main), f"origin/{default_branch}", cwd=self.bare)
        return True

    def remove(self, path):
        """Call with self.lock held."""
        git("worktree", "remove", "--force", str(path), cwd=self.bare, check=False)
        shutil.rmtree(path, ignore_errors=True)
        git("worktree", "prune", cwd=self.bare, check=False)


# ─── Claude ───


def run_claude(phase, prompt, cwd, out, schema, extra_args):
    """One Claude Code session in print mode. Every event goes to
    <out>/<phase>.jsonl (github-agent-watch follows it); returns the
    structured output it ended with, or raises."""
    env = {
        "HOME": CFG["home"],
        "PATH": CFG["path"],
        "LANG": "en_US.UTF-8",
        "SHELL": CFG["shell"],
        # Whitespace anywhere is dropped: a token copied from a terminal often
        # comes with a line break where it wrapped.
        "CLAUDE_CODE_OAUTH_TOKEN": "".join(Path(CFG["claudeTokenFile"]).read_text().split()),
        "NIX_SSL_CERT_FILE": CFG["caFile"],
        "SSL_CERT_FILE": CFG["caFile"],
    }
    transcript = out / f"{phase}.jsonl"
    cmd = [
        CFG["claude"], "-p",
        "--model", CFG["model"],
        "--output-format", "stream-json", "--verbose",
        "--json-schema", json.dumps(schema),
        "--add-dir", str(out),
        *extra_args,
    ]
    with open(transcript, "w") as stdout, open(out / f"{phase}.stderr", "w") as stderr:
        try:
            rc = subprocess.run(
                cmd, input=prompt, text=True, cwd=cwd, env=env, stdout=stdout, stderr=stderr,
                timeout=CFG["timeoutMinutes"] * 60,
            ).returncode
        except subprocess.TimeoutExpired:
            raise RuntimeError(f"{phase} timed out after {CFG['timeoutMinutes']} min") from None
    result = None
    for line in transcript.read_text().splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if event.get("type") == "result":
            result = event
    if rc or not result or result.get("structured_output") is None:
        sub = result and result.get("subtype")
        raise RuntimeError(f"{phase} exited {rc} ({sub}) without a result")
    return result["structured_output"]


# Answers to inline review comments, posted in their threads.
REPLIES = {
    "type": "array",
    "items": {
        "type": "object",
        "properties": {"comment_id": {"type": "integer"}, "body": {"type": "string"}},
        "required": ["comment_id", "body"],
    },
}

COORDINATOR_SCHEMA = {
    "type": "object",
    "properties": {
        "decision": {"type": "string", "enum": ["ask", "implement", "skip"]},
        "comment": {"type": "string"},
        "replies": REPLIES,
    },
    "required": ["decision", "comment"],
}

IMPLEMENTER_SCHEMA = {
    "type": "object",
    "properties": {
        "status": {"type": "string", "enum": ["done", "blocked"]},
        "title": {"type": "string"},
        "body": {"type": "string"},
        "summary": {"type": "string"},
        "replies": REPLIES,
    },
    "required": ["status", "summary"],
}


# ─── Jobs ───


def trusted(user, association):
    return association in TRUSTED_ASSOCIATIONS or user in CFG["trustedBots"]


def failed_run_logs(repo, texts, token):
    """The failed jobs' logs of the Actions runs the thread links to, since
    the agents can't reach GitHub themselves."""
    out = []
    runs = sorted({run for r, run in RUN_LINK.findall("\n".join(texts)) if r == repo})
    for run in runs:
        try:
            jobs = get_all(f"/repos/{repo}/actions/runs/{run}/jobs", token, key="jobs")
            for job in jobs:
                if job["conclusion"] != "failure":
                    continue
                text, _ = api("GET", f"/repos/{repo}/actions/jobs/{job['id']}/logs", token, raw=True)
                tail = "\n".join(text.splitlines()[-300:])
                out.append(f"\n## Failed job {job['name']} of run {run}\n\n```\n{tail}\n```\n")
        except RuntimeError as e:
            out.append(f"\n## Run {run}\n\n(couldn't fetch its logs: {e})\n")
    return "".join(out)


class Thread:
    """Everything said on an issue and, if any, on its PR, as the agents see
    it: trusted people's words and the agent's own earlier comments.
    `key` hashes only the former, so the agent's own words never retrigger
    it and an untrusted comment changes nothing."""

    def __init__(self, repo, token, me):
        self.repo, self.token, self.me = repo, token, me
        self.parts, self.hashed, self.texts = [], [], []
        # The PR's inline comments, which replies can go to.
        self.inline = set()
        # Who the agent answers to: the last person with write access who
        # spoke on the thread.
        self.person = None

    def add(self, heading, user, association, body, when="", ref=""):
        """`ref` is shown but not hashed, so adding it changed no item's key."""
        body = body or ""
        if user == self.me:
            self.parts.append(f"\n### {heading}{ref} by you (the agent) {when}\n\n{body}\n")
        elif trusted(user, association):
            if association in TRUSTED_ASSOCIATIONS:
                self.person = user
            self.parts.append(f"\n### {heading}{ref} by {user} {when}\n\n{body}\n")
            self.hashed.append(f"{heading}\0{user}\0{body}")
            self.texts.append(body)

    def add_issue(self, number, heading):
        for c in get_all(f"/repos/{self.repo}/issues/{number}/comments", self.token):
            self.add(heading, c["user"]["login"], c["author_association"], c["body"], c["created_at"])

    def add_pr(self, number):
        self.add_issue(number, "PR comment")
        for r in get_all(f"/repos/{self.repo}/pulls/{number}/reviews", self.token):
            if r.get("body"):
                self.add(f"Review ({r['state']})", r["user"]["login"], r["author_association"], r["body"], r.get("submitted_at") or "")
        for c in get_all(f"/repos/{self.repo}/pulls/{number}/comments", self.token):
            line = c.get("line") or c.get("original_line")
            self.inline.add(c["id"])
            ref = f" (comment_id {c['id']}" + (f", replying to {c['in_reply_to_id']})" if c.get("in_reply_to_id") else ")")
            self.add(f"Inline comment on {c['path']} line {line}", c["user"]["login"], c["author_association"], c["body"], c["created_at"], ref)

    @property
    def mention(self):
        return f"@{self.person} " if self.person else ""

    @property
    def key(self):
        return hashlib.sha256("\n\0\n".join(self.hashed).encode()).hexdigest()

    def text(self):
        return "".join(self.parts)


ITEM_LOCKS = {}


def item_lock(repo, number):
    with REPO_LOCKS_LOCK:
        return ITEM_LOCKS.setdefault((repo, number), threading.Lock())


def agent_branch_issue(pr, repo):
    """The issue number an agent PR is for, or None for anyone else's PR."""
    head = pr["head"]
    if head.get("repo") and head["repo"]["full_name"] == repo and head["ref"].startswith(BRANCH_PREFIX):
        rest = head["ref"][len(BRANCH_PREFIX):]
        if rest.isdigit():
            return int(rest)
    return None


def run_job(repo_full, installation, number, force, rebase=False):
    token = TOKENS.get(installation)
    issue = get(f"/repos/{repo_full}/issues/{number}", token)
    if "pull_request" in issue:
        pr = get(f"/repos/{repo_full}/pulls/{number}", token)
        for_issue = agent_branch_issue(pr, repo_full)
        if for_issue is not None:
            # Feedback on the agent's own PR is work on its issue.
            return run_job(repo_full, installation, for_issue, force, rebase)
    with item_lock(repo_full, number):
        work(repo_full, installation, token, issue, force, rebase)


def work(repo_full, installation, token, issue, force, rebase=False):
    """`rebase`: the PR's base moved and it no longer merges; with nothing
    else new, the run only rebases it."""
    number = issue["number"]
    repo = Repo(repo_full)
    meta = get(f"/repos/{repo_full}", token)
    is_pr = "pull_request" in issue
    kind = "pr" if is_pr else "issue"
    path = repo.worktree(kind, number)
    state_dir = Path(CFG["stateDir"]) / repo_full / str(number)
    if issue["state"] != "open" or LABEL not in labels_of(issue):
        cleanup(repo, path, state_dir)
        return

    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.json"
    state = json.loads(state_file.read_text()) if state_file.exists() else {}

    me = bot(token)["login"]
    thread = Thread(repo_full, token, me)
    if issue.get("author_association") in TRUSTED_ASSOCIATIONS:
        thread.person = issue["user"]["login"]
    elif meta["owner"]["type"] == "User":
        thread.person = meta["owner"]["login"]
    # Labelling an issue vouches for its body, whoever wrote it.
    thread.parts.append(f"# {'PR' if is_pr else 'Issue'} #{number}: {issue['title']}\n\n{issue.get('body') or ''}\n")
    thread.hashed.append(f"{issue['title']}\0{issue.get('body') or ''}")
    thread.texts.append(issue.get("body") or "")

    agent_pr = None
    if is_pr:
        pr = get(f"/repos/{repo_full}/pulls/{number}", token)
        if not pr["head"].get("repo") or pr["head"]["repo"]["full_name"] != repo_full:
            if state.get("fork") != number:
                comment(repo_full, number, token, "I can't push to a fork's branch, so I'm leaving this PR alone." + MARKER)
                state["fork"] = number
                state_file.write_text(json.dumps(state))
            return
        branch, base = pr["head"]["ref"], pr["base"]["ref"]
        thread.add_pr(number)
        feedback_on = number
    else:
        branch, base = f"{BRANCH_PREFIX}{number}", meta["default_branch"]
        thread.add_issue(number, "Comment")
        owner = repo_full.split("/")[0]
        prs = get(f"/repos/{repo_full}/pulls?state=open&head={owner}:{urllib.parse.quote(branch)}", token)
        agent_pr = prs[0] if prs else None
        if agent_pr:
            thread.parts.append(f"\n## Your open PR for this issue: {agent_pr['html_url']}\n\n{agent_pr.get('body') or ''}\n")
            thread.add_pr(agent_pr["number"])
        feedback_on = agent_pr["number"] if agent_pr else number
        markers = BASE_MARKER.findall("\n".join(thread.texts))
        if markers:
            base = markers[-1]

    key = thread.key
    # A new issue's plan waits for the owner's approval; feedback on the
    # agent's PR and labelled PRs don't. A plan approved as posted runs
    # without asking the coordinator again (even if the label came while
    # the plan was being made, which the queue doesn't force); a changed
    # thread is re-planned.
    gated = not is_pr and not agent_pr
    approved = PLAN_APPROVED in labels_of(issue)
    saved = state.pop("plan", None)
    resumed = gated and approved and saved is not None and saved["key"] == key
    unchanged = not force and not resumed and state.get("key") == key
    if unchanged and not rebase:
        return
    rebase_only = unchanged
    log(f"{repo_full}#{number}: {issue['title']}")
    state["key"] = key  # handled whatever the outcome; a change reruns it
    state_file.write_text(json.dumps(state))

    out = state_dir / time.strftime("%Y%m%d-%H%M%S")
    out.mkdir()
    context = out / "context.md"

    with repo.lock:
        if not repo.sync(token, meta["default_branch"]):
            comment(repo_full, number, token, "The repository has no commits yet, so there's no branch to start from. Push a first commit and label this again." + MARKER)
            return
        if not rev(f"origin/{base}", repo.bare):
            base = meta["default_branch"]
        repo.remove(path)
        remote = rev(f"origin/{branch}", repo.bare)
        git("worktree", "add", "--quiet", "--force", "-B", branch, str(path), f"origin/{branch}" if remote else f"origin/{base}", cwd=repo.bare)

    logs = failed_run_logs(repo_full, thread.texts, token)
    context.write_text(
        f"Repository: {repo_full} (default branch {meta['default_branch']})\n"
        f"Your branch: {branch}, based on {base}\n\n{thread.text()}{logs}"
    )

    try:
        if rebase_only:
            decision = {"decision": "implement", "comment": f"Rebase onto origin/{base}, which changed and conflicts now. Change nothing else."}
        elif resumed:
            decision = saved["decision"]
        else:
            decision = run_claude(
                "coordinator",
                CFG["coordinatorPrompt"].replace("@CONTEXT_FILE@", str(context)),
                path, out, COORDINATOR_SCHEMA, CFG["coordinatorArgs"],
            )
        if decision["decision"] != "implement":
            feedback(repo_full, feedback_on, token, decision["comment"], decision.get("replies"), thread)
            set_needs_info(repo_full, number, token, decision["decision"] == "ask")
            return
        set_needs_info(repo_full, number, token, False)
        if gated and not approved:
            comment(repo_full, number, token, f"{thread.mention}**Plan**\n\n{decision['comment']}\n\nAdd the `{PLAN_APPROVED}` label to go ahead.{MARKER}")
            state["plan"] = {"key": key, "decision": decision}
            state_file.write_text(json.dumps(state))
            return
        # Per-comment plans aren't posted: the implementer answers those
        # threads once it's done. A resumed plan already was.
        if decision["comment"].strip() and not (rebase_only or resumed):
            comment(repo_full, feedback_on, token, "**Plan**\n\n" + decision["comment"] + MARKER)

        # Every run starts from the base's tip. A conflict is the
        # implementer's to resolve; it's told so.
        rebased = git("rebase", "--quiet", f"origin/{base}", cwd=path, check=False)
        rebase_note = ""
        if rebased.returncode:
            git("rebase", "--abort", cwd=path, check=False)
            rebase_note = (
                f"\n\n## Rebase needed\n\nYour branch conflicts with origin/{base}. Before anything else, run "
                f"`git rebase origin/{base}`, resolve the conflicts and `git rebase --continue` until done.\n"
            )
        per_comment = "".join(f"\n- On inline comment {r['comment_id']}: {r['body']}" for r in decision.get("replies") or [])
        plan = f"\n\n## The plan you agreed on\n\n{decision['comment']}\n{per_comment}\n{rebase_note}"
        with open(context, "a") as f:
            f.write(plan)
        if rebase_only and not rebased.returncode:
            # GitHub merges, git rebases: what conflicts for one can apply
            # cleanly for the other.
            result = {"status": "done", "summary": f"Rebased onto `{base}`."}
        else:
            result = run_claude(
                "implementer",
                CFG["implementerPrompt"].replace("@CONTEXT_FILE@", str(context)),
                path, out, IMPLEMENTER_SCHEMA, CFG["implementerArgs"],
            )
        if rebase_only:
            # The PR is still about what it was; keep its title and body.
            result.pop("title", None)
            result.pop("body", None)
        publish(repo, path, installation, issue, is_pr, branch, base, remote, feedback_on, result, thread)
    except Exception as e:
        log(traceback.format_exc())
        try:
            comment(repo_full, feedback_on, TOKENS.get(installation), f"{thread.mention}I failed: {e}\n\nLog: `github-agent-watch {repo_full}#{number}`, `/var/log/github-agent.err`{MARKER}")
        except Exception:
            log(traceback.format_exc())


def publish(repo, path, installation, issue, is_pr, branch, base, remote, feedback_on, result, thread):
    repo_full, number = repo.full, issue["number"]
    # A fresh token: the agents may have run for most of the last one's hour.
    token = TOKENS.get(installation)
    head = rev("HEAD", path)
    ahead = int(git("rev-list", "--count", f"origin/{base}..HEAD", cwd=path).stdout.strip())
    replies = result.get("replies")
    if result["status"] != "done" or ahead == 0:
        # Blocked: the summary says what's needed; always say it.
        feedback(repo_full, feedback_on, token, result["summary"] or "I'm blocked; see the replies.", replies, thread)
        set_needs_info(repo_full, number, token, True)
        return
    if head != remote:
        # The lease refuses to overwrite a push made in the meantime.
        git("push", "--quiet", f"--force-with-lease=refs/heads/{branch}:{remote or ''}", "origin", f"HEAD:refs/heads/{branch}", cwd=path, token=token)
    if is_pr:
        feedback(repo_full, number, token, result["summary"], replies, thread)
        review(repo_full, number, token, thread)
        return
    title = result.get("title") or issue["title"]
    body = f"{result.get('body') or result['summary']}\n\nCloses #{number}"
    if feedback_on != number:
        if result.get("title") or result.get("body"):
            api("PATCH", f"/repos/{repo_full}/pulls/{feedback_on}", token, {"title": title, "body": body})
        feedback(repo_full, feedback_on, token, result["summary"], replies, thread)
        review(repo_full, feedback_on, token, thread)
        return
    pr, _ = api("POST", f"/repos/{repo_full}/pulls", token, {"title": title, "head": branch, "base": base, "body": body})
    api("POST", f"/repos/{repo_full}/issues/{pr['number']}/labels", token, {"labels": [LABEL]})
    review(repo_full, pr["number"], token, thread)


def review(repo_full, number, token, thread):
    """(Re-)request a review: GitHub's own way to say a PR is ready for you."""
    if not thread.person:
        return
    try:
        # GitHub refuses a review request to the PR's own author.
        if get(f"/repos/{repo_full}/pulls/{number}", token)["user"]["login"] == thread.person:
            return
        api("POST", f"/repos/{repo_full}/pulls/{number}/requested_reviewers", token, {"reviewers": [thread.person]})
    except RuntimeError as e:
        log(f"{repo_full}#{number}: review request: {e}")


def squash_title(repo_full, base, pr, token):
    """The squash commit's title: the PR title (written in the repo's commit
    style), with GitHub's " (#n)" suffix only if the branch's recent commits
    carry one, or it has no history to go by."""
    commits = get(f"/repos/{repo_full}/commits?sha={urllib.parse.quote(base)}&per_page=20", token)
    firsts = [c["commit"]["message"].split("\n", 1)[0] for c in commits if len(c["parents"]) < 2]
    suffixed = sum(bool(re.search(r"\(#\d+\)$", f)) for f in firsts)
    title = re.sub(r"\s*\(#\d+\)$", "", pr["title"])
    return f"{title} (#{pr['number']})" if not firsts or 2 * suffixed > len(firsts) else title


def approved_head(repo_full, pr, approved_sha, approved_at, token):
    """The head an approval covers. GitHub records the commit the reviewer's
    page had loaded, which lags when the agent pushed while it was open: a
    newer head counts too if it was committed before the approval."""
    head = pr["head"]["sha"]
    if head == approved_sha:
        return head
    commit = get(f"/repos/{repo_full}/commits/{head}", token)["commit"]
    when = datetime.datetime.fromisoformat
    if when(commit["committer"]["date"]) < when(approved_at):
        return head
    raise RuntimeError("it changed after the approval; approve the latest commit")


def merge(repo_full, installation, number, approved_sha, approved_at, reviewer):
    """A trusted approval squash-merges the PR as it was when approved."""
    token = TOKENS.get(installation)
    pr = get(f"/repos/{repo_full}/pulls/{number}", token)
    issue = agent_branch_issue(pr, repo_full)
    # Not while a job is pushing to it.
    with item_lock(repo_full, issue if issue is not None else number):
        pr = get(f"/repos/{repo_full}/pulls/{number}", token)
        if pr["state"] != "open":
            return
        try:
            sha = approved_head(repo_full, pr, approved_sha, approved_at, token)
            # sha: GitHub refuses if the head moves under us.
            api("PUT", f"/repos/{repo_full}/pulls/{number}/merge", token, {
                "merge_method": "squash",
                "sha": sha,
                "commit_title": squash_title(repo_full, pr["base"]["ref"], pr, token),
                "commit_message": "",
            })
        except RuntimeError as e:
            comment(repo_full, number, token, f"@{reviewer} I couldn't merge this: {e}{MARKER}")
            return
        if issue is not None:
            try:
                api("DELETE", f"/repos/{repo_full}/git/refs/heads/{urllib.parse.quote(pr['head']['ref'])}", token)
            except RuntimeError:
                pass  # already gone (the repo deletes merged branches)


def cleanup(repo, path, state_dir):
    """Done with an item: drop its worktree and its run logs. Labelling it
    again starts over."""
    if repo.bare.exists():
        with repo.lock:
            repo.remove(path)
    shutil.rmtree(state_dir, ignore_errors=True)


# ─── Queue ───


class Queue:
    """At most `concurrency` jobs at once, one per item; an item that comes
    in again while queued is queued once, and while running runs again
    after."""

    def __init__(self, workers):
        self.cv = threading.Condition()
        self.pending = {}
        self.running = set()
        for _ in range(workers):
            threading.Thread(target=self.loop, daemon=True).start()

    def put(self, repo, installation, number, force=False, rebase=False):
        with self.cv:
            key = (repo, number)
            prev = self.pending.get(key)
            # A label added while the item runs (an issue opened with it,
            # unlabel + label) is covered by that run; forcing another would
            # repeat it.
            force = force and key not in self.running
            self.pending[key] = (installation, force or (prev is not None and prev[1]), rebase or (prev is not None and prev[2]))
            self.cv.notify()

    def loop(self):
        while True:
            with self.cv:
                while not (ready := [k for k in self.pending if k not in self.running]):
                    self.cv.wait()
                key = ready[0]
                installation, force, rebase = self.pending.pop(key)
                self.running.add(key)
            try:
                run_job(key[0], installation, key[1], force, rebase)
            except Exception:
                log(f"{key[0]}#{key[1]}: {traceback.format_exc()}")
            finally:
                with self.cv:
                    self.running.discard(key)
                    self.cv.notify_all()


QUEUE = Queue(CFG["concurrency"])


def refresh(repo_full, installation, branch):
    """A push: move the reference checkout to the default branch, and rebase
    the labelled PRs onto the pushed branch that it left conflicting."""
    try:
        token = TOKENS.get(installation)
        default = get(f"/repos/{repo_full}", token)["default_branch"]
        repo = Repo(repo_full)
        if branch == default and repo.bare.exists():
            with repo.lock:
                repo.sync(token, default)
        prs = get_all(f"/repos/{repo_full}/pulls?state=open&base={urllib.parse.quote(branch)}", token)
        for pr in prs:
            if LABEL not in labels_of(pr):
                continue
            # GitHub works mergeability out in the background after a push.
            for _ in range(12):
                mergeable = get(f"/repos/{repo_full}/pulls/{pr['number']}", token)["mergeable"]
                if mergeable is not None:
                    break
                time.sleep(10)
            if mergeable is False:
                QUEUE.put(repo_full, installation, pr["number"], rebase=True)
    except Exception:
        log(f"refresh {repo_full}: {traceback.format_exc()}")


def reconcile():
    """Hourly, and at startup: queue every open labelled item in every repo
    the App can see (unchanged ones are skipped by their key), refresh the
    clones, and drop worktrees and run logs whose item is gone, and the
    clones and logs of repos the App no longer sees (deleted, or removed from
    the installation). Catches deliveries that never arrived."""
    seen = set()
    complete = True  # every repo listed: only then is a missing one gone
    for inst in get_all("/app/installations", app_jwt()):
        try:
            token = TOKENS.get(inst["id"])
            for meta in get_all("/installation/repositories", token, key="repositories"):
                full = meta["full_name"]
                seen.add(full)
                if meta["archived"]:
                    continue
                items = get_all(f"/repos/{full}/issues?state=open&labels={urllib.parse.quote(LABEL)}", token)
                for item in items:
                    QUEUE.put(full, inst["id"], item["number"])
                prune_state(full, {i["number"] for i in items})
                repo = Repo(full)
                if not repo.bare.exists():
                    continue
                keep = {f"{'pr' if 'pull_request' in i else 'issue'}-{i['number']}" for i in items}
                with repo.lock:
                    repo.sync(token, meta["default_branch"])
                    for path in repo.dir.iterdir():
                        if re.fullmatch(r"(issue|pr)-\d+", path.name) and path.name not in keep:
                            repo.remove(path)
        except Exception:
            complete = False
            log(f"reconcile installation {inst['id']}: {traceback.format_exc()}")
    if complete:
        prune_repos(seen)


def prune_state(full, keep):
    """Drop the run logs of items no longer open and labelled, skipping one
    that is running (its job cleans up after itself)."""
    root = Path(CFG["stateDir"]) / full
    if not root.is_dir():
        return
    for path in root.iterdir():
        if not path.name.isdigit() or int(path.name) in keep:
            continue
        lock = item_lock(full, int(path.name))
        if lock.acquire(blocking=False):
            try:
                shutil.rmtree(path, ignore_errors=True)
            finally:
                lock.release()


def prune_repos(seen):
    """Delete the clone and run logs of every repo not in `seen`."""
    for base in (Path(CFG["reposDir"]), Path(CFG["stateDir"])):
        if not base.is_dir():
            continue
        for owner in base.iterdir():
            if not owner.is_dir():
                continue
            for path in owner.iterdir():
                full = f"{owner.name}/{path.name}"
                # Recently touched: a repo installed after the listing above
                # may be cloning or working right now.
                if full in seen or time.time() - path.stat().st_mtime < 86400:
                    continue
                log(f"{full}: no longer installed, deleting {path}")
                with Repo(full).lock:
                    shutil.rmtree(path, ignore_errors=True)
            if not any(owner.iterdir()):
                owner.rmdir()


def reconcile_loop():
    while True:
        try:
            reconcile()
        except Exception:
            log(f"reconcile: {traceback.format_exc()}")
        time.sleep(3600)


# ─── Webhook ───


def route(event, p):
    """Which deliveries become work. The job rereads everything from GitHub,
    so a payload only says where to look."""
    repo = (p.get("repository") or {}).get("full_name")
    installation = (p.get("installation") or {}).get("id")
    if not repo or not installation:
        return 204
    action = p.get("action")
    sender = (p.get("sender") or {}).get("login")
    if event == "push":
        # Its own pushes count: its merges move base branches too.
        ref = p.get("ref") or ""
        if ref.startswith("refs/heads/") and not p.get("deleted"):
            threading.Thread(target=refresh, args=(repo, installation, ref.removeprefix("refs/heads/")), daemon=True).start()
            return 202
        return 204
    if sender == BOT.get("login"):
        return 204  # its own comments and labels
    item = p.get("issue") or p.get("pull_request")
    if not item:
        return 204
    review = p.get("review") or {}
    if event == "pull_request_review" and action == "submitted" and (review.get("state") or "").lower() == "approved":
        if LABEL in labels_of(item) and trusted(review["user"]["login"], review.get("author_association")):
            threading.Thread(target=merge, args=(repo, installation, item["number"], review["commit_id"], review["submitted_at"], review["user"]["login"]), daemon=True).start()
            return 202
        return 204
    number = item["number"]
    added = (p.get("label") or {}).get("name") if action == "labeled" else None
    relabelled = added == LABEL
    if action in ("closed", "unlabeled") or relabelled or LABEL in labels_of(item):
        # Closing or unlabelling cleans up; labelling (again) or approving
        # the plan forces a run.
        QUEUE.put(repo, installation, number, force=relabelled or added == PLAN_APPROVED)
        return 202
    return 204


class Handler(BaseHTTPRequestHandler):
    def reply(self, code):
        self.send_response(code)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_POST(self):  # noqa: N802 (http.server's naming)
        length = self.headers.get("Content-Length", "")
        if not length.isdigit():
            return self.reply(400)
        if int(length) > 25 * 1024 * 1024:  # GitHub's own cap
            return self.reply(413)
        body = self.rfile.read(int(length))
        secret = Path(CFG["webhookSecretFile"]).read_text().strip().encode()
        expected = "sha256=" + hmac.new(secret, body, hashlib.sha256).hexdigest()
        if not hmac.compare_digest(self.headers.get("X-Hub-Signature-256", ""), expected):
            return self.reply(401)
        try:
            code = route(self.headers.get("X-GitHub-Event", ""), json.loads(body))
        except Exception:
            log(traceback.format_exc())
            code = 500
        self.reply(code)

    def log_message(self, fmt, *args):
        log(f"webhook: {fmt % args}")


def main():
    # Put a name to the bot early, so route() can drop its own deliveries.
    for inst in get_all("/app/installations", app_jwt())[:1]:
        bot(TOKENS.get(inst["id"]))
    threading.Thread(target=reconcile_loop, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", CFG["port"]), Handler).serve_forever()


if __name__ == "__main__":
    main()
