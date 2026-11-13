#!/usr/bin/env bash
# Usage:
#   notify.sh find <title>             print the number of the open issue titled <title>
#   notify.sh issue <title>            body on stdin; comment on that issue, or open
#                                      it labelled `agent` for home-server's issue agent
#   notify.sh close <title> <comment>  close that issue, if open
#   notify.sh telegram <text>          message the TELEGRAM_CHAT_ID chat
#
# The issue commands need GH_TOKEN and GH_REPO. Telegram is skipped unless
# TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are set, and a failed send only
# warns: a notification must never fail the run it reports on.
set -euo pipefail

find_issue() {
  # The search is fuzzy; match the title exactly.
  gh issue list --state open --search "in:title \"$1\"" --json number,title |
    TITLE=$1 jq -r 'map(select(.title == env.TITLE)) | .[0].number // empty'
}

case "${1:-}" in
  find) find_issue "$2" ;;
  issue)
    body=$(cat)
    n=$(find_issue "$2")
    if [ -n "$n" ]; then
      gh issue comment "$n" --body "$body"
    else
      # Only if missing (it fails when the label exists); leaves yours alone.
      gh label create agent --color de7356 \
        --description "To be handled by an agent" >/dev/null 2>&1 || true
      gh issue create --title "$2" --body "$body" --label agent
    fi
    ;;
  close)
    n=$(find_issue "$2")
    if [ -n "$n" ]; then
      gh issue close "$n" --comment "$3"
    fi
    ;;
  telegram)
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
      echo "Telegram secrets not set, skipping"
      exit 0
    fi
    # Telegram caps a message at 4096 characters.
    text=$2
    curl -fsS "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
      --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
      --data-urlencode "text=${text:0:4000}" \
      >/dev/null || echo "::warning::Telegram notification failed"
    ;;
  *)
    sed -n '2,7p' "$0" >&2
    exit 2
    ;;
esac
