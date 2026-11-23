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
# A checklist line in an issue body, as plans written as issues use them
# (`## Work` steps, `## Decisions`): "- [ ] text" or "- [x] text", the
# latter maybe naming its commits: "(abc1234)", "(abc1234 on <branch>)".
CHECK = re.compile(r"^(\s*[-*+] \[)([ xX])(\] )(.*?)(\s+\([0-9a-f]{7,40}(?:, [0-9a-f]{7,40})*(?: on [\w./-]+)?\))?\s*$")


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


def lines_of(body):
    return (body or "").replace("\r\n", "\n").split("\n")


def normalize(body):
    """An issue body as its key sees it: without checkbox states or commit
    suffixes, so ticking a step (the agent's, a script's or the owner's)
    starts no new round."""
    # Line endings kept: a body without ticks hashes as it always did.
    out = []
    for line in (body or "").split("\n"):
        cr = "\r" if line.endswith("\r") else ""
        m = CHECK.match(line.removesuffix("\r"))
        out.append(f"{m[1]} {m[3]}{m[4]}{cr}" if m else line)
    return "\n".join(out)


def checklist(body):
    """The body's checklist items, in order, with the `##` section each is in."""
    items, section = [], ""
    for line in lines_of(body):
        if line.startswith("## "):
            section = line[3:].strip()
        elif m := CHECK.match(line):
            items.append({"section": section, "done": m[2] != " ", "text": m[4]})
    return items


def sentence(text):
    return text.strip().rstrip(".") + "."


def edit_checklist(body, items, done, decisions, replaced):
    """`body` with the `done` items (indices into `items`) ticked, the
    `replaced` decisions struck through and the new `decisions` added at the
    end of `## Decisions`. Items are found by their text: the body may have
    been edited since `items` was read from it."""
    lines = lines_of(body)

    def find(i):
        for n, line in enumerate(lines):
            m = CHECK.match(line)
            if m and m[4] == items[i]["text"]:
                return n, m
        return None, None

    for i in done:
        n, m = find(i)
        if m and m[2] == " ":
            lines[n] = f"{m[1]}x{m[3]}{m[4]}"
    for r in replaced:
        n, m = find(r["item"])
        if m and not m[4].startswith("~~"):
            lines[n] = f"{m[1]} {m[3]}~~{m[4]}~~ Replaced by {r['by'].strip()}: {sentence(r['why'])}"
    new = [f"- [x] {d['decision'].strip().rstrip('.:')}: {sentence(d['why'])}" for d in decisions]
    if new:
        heads = [n for n, line in enumerate(lines) if line.startswith("## ")]
        start = next((n for n in heads if lines[n][3:].strip() == "Decisions"), None)
        if start is not None:
            end = next((n for n in heads if n > start), len(lines))
            while end > start + 1 and not lines[end - 1].strip():
                end -= 1
            lines[end:end] = new
        else:
            # Before the work, or else at the end, ahead of any trailing
            # HTML comments (a plan script's marker).
            at = next((n for n in heads if lines[n][3:].strip() == "Work"), None)
            if at is None:
                at = len(lines)
                while at and (not lines[at - 1].strip() or lines[at - 1].startswith("<!--")):
                    at -= 1
                lines[at:at] = ["", "## Decisions", *new]
            else:
                lines[at:at] = ["## Decisions", *new, ""]
    return "\n".join(lines)


def related(repo, number, issue, me, token):
    """Where the issue sits in a plan: its labels, milestone, parent,
    sub-issues and blockers, as context, and its blockers' states, which
    its key hashes (one closing is news). A parent's body is only shown if
    someone trusted wrote it."""
    def ref(i):
        other = i["repository_url"].removeprefix(f"{API}/repos/")
        return f"{'' if other == repo else other}#{i['number']} {i['title']} ({i['state']})"

    out = []
    if labels := sorted(labels_of(issue) - {LABEL, NEEDS_INFO, PLAN_APPROVED}):
        out.append(f"Labels: {', '.join(labels)}")
    if ms := issue.get("milestone"):
        out.append(f"Milestone: {ms['title']}" + (f" (due {ms['due_on'][:10]})" if ms.get("due_on") else "") + (f": {ms['description']}" if ms.get("description") else ""))
    if issue.get("parent_issue_url"):
        p = get(issue["parent_issue_url"], token)
        out.append(f"Parent: {ref(p)}")
        if p["user"]["login"] == me or trusted(p["user"]["login"], p.get("author_association")):
            out.append(f"\n{p.get('body') or ''}\n")
    if (issue.get("sub_issues_summary") or {}).get("total"):
        out.append("Sub-issues:\n" + "\n".join(f"- {ref(s)}" for s in get_all(f"/repos/{repo}/issues/{number}/sub_issues", token)))
    blockers = []
    if (issue.get("issue_dependencies_summary") or {}).get("total_blocked_by"):
        blockers = get_all(f"/repos/{repo}/issues/{number}/dependencies/blocked_by", token)
        out.append("Blocked by:\n" + "\n".join(f"- {ref(b)}" for b in blockers))
    text = "\n## Where this issue sits\n\n" + "\n".join(out) + "\n" if out else ""
    return text, sorted(f"{b['repository_url']}#{b['number']} {b['state']}" for b in blockers)


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
    # The agents can write the clone (a dev shell installs its hooks into
    # .bare/hooks), and what they put there must not run here, outside their
    # sandbox, as the user that can read the App's key: no hooks, no fsmonitor.
    safe = ["-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false"]
    r = subprocess.run([CFG["git"], *safe, *args], cwd=cwd, env=env, capture_output=True, text=True)
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
    cache = f"{CFG['home']}/.cache"
    env = {
        "HOME": CFG["home"],
        "PATH": CFG["path"],
        # The sandbox only lets them write the repos and ~/.cache; these
        # default to elsewhere in $HOME.
        "XDG_CACHE_HOME": cache,
        "CARGO_HOME": f"{cache}/cargo",
        "GOPATH": f"{cache}/go",
        "GOCACHE": f"{cache}/go-build",
        "npm_config_cache": f"{cache}/npm",
        # Lets a repo's dev shell skip what can't work here, like installing
        # git hooks into the clone the sandbox keeps read-only.
        "GITHUB_AGENT": "1",
        "LANG": "en_US.UTF-8",
        "SHELL": CFG["shell"],
        # Whitespace anywhere is dropped: a token copied from a terminal often
        # comes with a line break where it wrapped.
        "CLAUDE_CODE_OAUTH_TOKEN": "".join(Path(CFG["claudeTokenFile"]).read_text().split()),
        "NIX_SSL_CERT_FILE": CFG["caFile"],
        "SSL_CERT_FILE": CFG["caFile"],
    }
    transcript = out / f"{phase}.jsonl"
    extra_args = protect_clone(phase, extra_args, Path(cwd).parent / ".bare", out)
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


def protect_clone(phase, args, bare, out):
    """Add the clone's config and hooks to the sandbox's denyWrite: Claude
    Code protects .git/config and .git/hooks itself, but this clone is
    `.bare`. The dispatcher's own git reads that config."""
    args = list(args)
    i = args.index("--settings") + 1
    settings = json.loads(Path(args[i]).read_text())
    fs = settings.setdefault("sandbox", {}).setdefault("filesystem", {})
    fs["denyWrite"] = [*fs.get("denyWrite", []), str(bare / "config"), str(bare / "hooks")]
    args[i] = str(out / f"{phase}-settings.json")
    Path(args[i]).write_text(json.dumps(settings))
    return args


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
        # The issue's checklist, by the numbers the context gives its items.
        "steps": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"commit": {"type": "string"}, "items": {"type": "array", "items": {"type": "integer"}}},
                "required": ["commit", "items"],
            },
        },
        "decisions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"decision": {"type": "string"}, "why": {"type": "string"}},
                "required": ["decision", "why"],
            },
        },
        "replaced": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"item": {"type": "integer"}, "by": {"type": "string"}, "why": {"type": "string"}},
                "required": ["item", "by", "why"],
            },
        },
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
        self.issue = None
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

    def set_issue(self, title, body):
        """The issue's title and body, always the key's first entry."""
        self.issue = f"{title}\0{normalize(body)}"

    @property
    def mention(self):
        return f"@{self.person} " if self.person else ""

    @property
    def key(self):
        return hashlib.sha256("\n\0\n".join([self.issue, *self.hashed] if self.issue else self.hashed).encode()).hexdigest()

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
    thread.set_issue(issue["title"], issue.get("body"))
    thread.texts.append(issue.get("body") or "")
    # An issue's checklist, which the agent keeps: ticked as its commits are
    # pushed, decisions added and replaced ones struck through.
    items = [] if is_pr else checklist(issue.get("body"))
    where, blockers = ("", []) if is_pr else related(repo_full, number, issue, me, token)
    if blockers:
        thread.hashed.append("blocked by\0" + "\n".join(blockers))

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
        start = base
        thread.add_pr(number)
        feedback_on = number
    else:
        # `base` is what the PR goes into, `start` what the branch starts
        # from: an `agent-base` branch (the flake update's failed
        # candidate) is built on but not merged into, so its commits land
        # on the default branch together with the fix.
        branch, base = f"{BRANCH_PREFIX}{number}", meta["default_branch"]
        start = base
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
            start = markers[-1]

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
    if not rebase_only and any(b.endswith(" open") for b in blockers):
        log(f"{repo_full}#{number}: blocked by an open issue, waiting")
        return

    out = state_dir / time.strftime("%Y%m%d-%H%M%S")
    out.mkdir()
    context = out / "context.md"

    with repo.lock:
        if not repo.sync(token, meta["default_branch"]):
            comment(repo_full, number, token, "The repository has no commits yet, so there's no branch to start from. Push a first commit and label this again." + MARKER)
            return
        if not rev(f"origin/{base}", repo.bare):
            base = meta["default_branch"]
        if not rev(f"origin/{start}", repo.bare):
            start = base
        repo.remove(path)
        remote = rev(f"origin/{branch}", repo.bare)
        git("worktree", "add", "--quiet", "--force", "-B", branch, str(path), f"origin/{branch}" if remote else f"origin/{start}", cwd=repo.bare)

    logs = failed_run_logs(repo_full, thread.texts, token)
    started = "" if start == base else f", started from {start} (its commits go into the PR too)"
    context.write_text(
        f"Repository: {repo_full} (default branch {meta['default_branch']})\n"
        f"Your branch: {branch}, for a PR into {base}{started}\n\n{thread.text()}{where}{checklist_text(items)}{logs}"
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
            # Only a question is posted; a skip is only logged.
            text = decision["comment"] if decision["decision"] == "ask" else ""
            if not text:
                log(f"{repo_full}#{number}: skipped: {decision['comment']}")
            feedback(repo_full, feedback_on, token, text, decision.get("replies"), thread)
            set_needs_info(repo_full, number, token, decision["decision"] == "ask")
            return
        set_needs_info(repo_full, number, token, False)
        if gated and not approved:
            comment(repo_full, number, token, f"{thread.mention}**Plan**\n\n{decision['comment']}\n\nAdd the `{PLAN_APPROVED}` label to go ahead.{MARKER}")
            state["plan"] = {"key": key, "decision": decision}
            state_file.write_text(json.dumps(state))
            return
        # Only a plan that waits for approval is posted: the work itself
        # answers the rest.

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
        body = publish(repo, path, installation, issue, is_pr, branch, base, start, remote, feedback_on, result, thread, items)
        if body is not None:
            # The agent's own edit to the checklist isn't news; anyone
            # else's during the run is, and leaves the key to rerun it.
            thread.set_issue(issue["title"], body)
            state["key"] = thread.key
            state_file.write_text(json.dumps(state))
    except Exception as e:
        log(traceback.format_exc())
        try:
            comment(repo_full, feedback_on, TOKENS.get(installation), f"{thread.mention}I failed: {e}\n\nLog: `github-agent-watch {repo_full}#{number}`, `/var/log/github-agent.err`{MARKER}")
        except Exception:
            log(traceback.format_exc())


def publish(repo, path, installation, issue, is_pr, branch, base, start, remote, feedback_on, result, thread, items):
    """Push, open or update the PR, and keep the issue's checklist. Returns
    the issue body the agent wrote, if it edited one the run started from."""
    repo_full, number = repo.full, issue["number"]
    # A fresh token: the agents may have run for most of the last one's hour.
    token = TOKENS.get(installation)
    # From the clone, by branch name: the worktree's .git file is the
    # implementer's to rewrite and could point git at a config of its own.
    head = rev(f"refs/heads/{branch}", repo.bare)
    # The agent's own commits: past what it started from, even once a
    # rebase onto `base` has rewritten the start branch's commits.
    ahead = int(git("rev-list", "--count", "--cherry-pick", "--right-only", f"origin/{start}...refs/heads/{branch}", cwd=repo.bare).stdout.strip())
    replies = result.get("replies")
    if result["status"] != "done" or ahead == 0:
        # Blocked: the summary says what's needed; always say it.
        feedback(repo_full, feedback_on, token, result["summary"] or "I'm blocked; see the replies.", replies, thread)
        set_needs_info(repo_full, number, token, True)
        return None
    if head != remote:
        # The lease refuses to overwrite a push made in the meantime.
        git("push", "--quiet", f"--force-with-lease=refs/heads/{branch}:{remote or ''}", "origin", f"refs/heads/{branch}:refs/heads/{branch}", cwd=repo.bare, token=token)
    if is_pr:
        feedback(repo_full, number, token, "", replies, thread)
        review(repo_full, number, token, thread)
        return None
    body = keep_checklist(repo, issue, start, branch, result, items, token)
    title = result.get("title") or issue["title"]
    pr_body = f"{result.get('body') or result['summary']}\n\nCloses #{number}"
    if feedback_on != number:
        if result.get("title") or result.get("body"):
            api("PATCH", f"/repos/{repo_full}/pulls/{feedback_on}", token, {"title": title, "body": pr_body})
        feedback(repo_full, feedback_on, token, "", replies, thread)
        review(repo_full, feedback_on, token, thread)
        return body
    pr, _ = api("POST", f"/repos/{repo_full}/pulls", token, {"title": title, "head": branch, "base": base, "body": pr_body})
    api("POST", f"/repos/{repo_full}/issues/{pr['number']}/labels", token, {"labels": [LABEL]})
    review(repo_full, pr["number"], token, thread)
    return body


def keep_checklist(repo, issue, base, branch, result, items, token):
    """Tick the Work steps the pushed commits cover and record the decisions
    the implementer made or replaced, by editing the issue body: no comment.
    Only commits on the pushed branch count. Returns the new body if the
    body is still the one the run started from, else None."""
    if not items:
        return None
    done = set()
    for s in result.get("steps") or []:
        sha = rev(s["commit"], repo.bare)
        pushed = sha and not git("merge-base", "--is-ancestor", sha, f"refs/heads/{branch}", cwd=repo.bare, check=False).returncode
        new = pushed and git("merge-base", "--is-ancestor", sha, f"origin/{base}", cwd=repo.bare, check=False).returncode
        if new:
            done |= {i - 1 for i in s["items"] if 0 < i <= len(items) and items[i - 1]["section"] == "Work"}
    replaced = [r | {"item": r["item"] - 1} for r in result.get("replaced") or [] if 0 < r["item"] <= len(items) and items[r["item"] - 1]["section"] == "Decisions"]
    decisions = result.get("decisions") or []
    if not (done or replaced or decisions):
        return None
    number = issue["number"]
    current = get(f"/repos/{repo.full}/issues/{number}", token)
    body = edit_checklist(current.get("body") or "", items, done, decisions, replaced)
    if body != "\n".join(lines_of(current.get("body"))):
        api("PATCH", f"/repos/{repo.full}/issues/{number}", token, {"body": body})
    same = (current["title"], normalize(current.get("body"))) == (issue["title"], normalize(issue.get("body")))
    return body if same else None


def checklist_text(items):
    if not items:
        return ""
    rows = "\n".join(f"{n}. [{i['section'] or 'no section'}] [{'x' if i['done'] else ' '}] {i['text']}" for n, i in enumerate(items, 1))
    return f"\n## The issue's checklist\n\nRefer to items by these numbers.\n\n{rows}\n"


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


RUN_PASSED = {"success", "skipped", "neutral"}


def runs_passed(repo_full, installation, sha, hours=24):
    """Wait for every Actions run on `sha` to finish, the latest of each
    workflow and event counting; None if they all passed, else what didn't.
    A run waiting on an environment's approval (Build on a PR) waits for
    it."""
    deadline = time.time() + hours * 3600
    while True:
        runs = get_all(f"/repos/{repo_full}/actions/runs?head_sha={sha}", TOKENS.get(installation), key="workflow_runs")
        latest = {}
        for r in runs:
            k = (r["workflow_id"], r["event"])
            if k not in latest or r["id"] > latest[k]["id"]:
                latest[k] = r
        if all(r["status"] == "completed" for r in latest.values()):
            failed = [f"{r['name']} ({r['conclusion']}): {r['html_url']}" for r in latest.values() if r["conclusion"] not in RUN_PASSED]
            return "\n".join(failed) or None
        if time.time() > deadline:
            return f"its checks didn't finish within {hours} hours"
        time.sleep(60)


def merge(repo_full, installation, number, approved_sha, approved_at, reviewer):
    """A trusted approval squash-merges the PR as it was when approved, once
    its checks and builds pass."""
    token = TOKENS.get(installation)
    pr = get(f"/repos/{repo_full}/pulls/{number}", token)
    issue = agent_branch_issue(pr, repo_full)
    try:
        sha = approved_head(repo_full, pr, approved_sha, approved_at, token)
        # Outside the item's lock: this can take hours, and a job pushing
        # meanwhile makes the merge below refuse the moved head.
        if failed := runs_passed(repo_full, installation, sha):
            raise RuntimeError(f"not everything passed:\n\n{failed}")
    except RuntimeError as e:
        comment(repo_full, number, TOKENS.get(installation), f"@{reviewer} I couldn't merge this: {e}{MARKER}")
        return
    token = TOKENS.get(installation)
    # Not while a job is pushing to it.
    with item_lock(repo_full, issue if issue is not None else number):
        pr = get(f"/repos/{repo_full}/pulls/{number}", token)
        if pr["state"] != "open":
            return
        try:
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
