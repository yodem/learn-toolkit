#!/bin/bash
# Weekly Exa/Tavily drift check for learn-toolkit. Runs from cron on the dev server.
# Exit codes of check-backends.py: 0 clean, 1 breaking, 2 info, 3 probe error.
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.nvm/versions/node/v24.15.0/bin:/usr/local/bin:/usr/bin:/bin"
REPO="${LEARN_TOOLKIT_REPO:-$HOME/dev/learn-toolkit-check}"
REF="${CHECK_REF:-origin/main}"
DRY_RUN="${DRY_RUN:-0}"
DATE=$(date -u +%Y-%m-%d)
OUT="$HOME/scripts/learn-toolkit-check/$DATE"
TG_DIR="$HOME/.config/herdr/plugins/config/barnuri.telegram-notifications"
mkdir -p "$OUT"
log() { echo "[$(date -u +%FT%TZ)] $*"; }

notify() {  # $1 = text; uses the herdr Telegram plugin's own sender, token stays in its config
  local lib
  lib=$(ls -d "$HOME"/.config/herdr/plugins/github/barnuri.telegram-notifications-*/lib 2>/dev/null | head -1) || { log "telegram notify failed"; return 0; }
  [ -n "$lib" ] || { log "telegram notify failed"; return 0; }
  HERDR_PLUGIN_CONFIG_DIR="$TG_DIR" TG_TEXT="$1" LIB="$lib" timeout 20 node -e '
    const {loadConfig}=require(process.env.LIB+"/config");const {sendMessage}=require(process.env.LIB+"/telegram");
    const {botToken,chatId}=loadConfig();
    sendMessage({botToken,chatId,text:process.env.TG_TEXT}).catch(e=>{console.error("telegram: "+e.message);process.exit(1)})' \
    || log "telegram notify failed"
  return 0
}

if ! git -C "$REPO" fetch -q origin; then
  log "probe error: git fetch failed"
  notify "learn-toolkit weekly check could not run (git fetch failed)."
  exit 0
fi
WT=$(mktemp -d)
trap 'git -C "$REPO" worktree remove --force "$WT" >/dev/null 2>&1 || true' EXIT
if ! git -C "$REPO" worktree add -q --detach "$WT" "$REF"; then
  log "probe error: worktree setup failed"
  notify "learn-toolkit weekly check could not run (worktree setup failed)."
  exit 0
fi
P="$WT/plugins/learn-toolkit"

set +e
if [ -n "${CHECK_FORCE_EXIT:-}" ]; then echo '{"status":"forced","findings":[]}' > "$OUT/report.json"; rc=$CHECK_FORCE_EXIT
else python3 "$P/scripts/check-backends.py" --json > "$OUT/report.json"; rc=$?; fi
set -e
prefix=""; [ "$DRY_RUN" = 1 ] && prefix="dry-run: "
case "$rc" in
  0) log "${prefix}clean"; exit 0 ;;
  3) log "${prefix}probe error"; notify "learn-toolkit weekly check could not run (probe error). Report: $OUT/report.json"; exit 0 ;;
  1|2) ;;
  *) log "${prefix}unexpected exit $rc"; notify "learn-toolkit weekly check failed (exit $rc)"; exit 1 ;;
esac

BR="backend-drift/$DATE"; n=1
while git -C "$REPO" ls-remote --exit-code --heads origin "$BR" >/dev/null 2>&1; do n=$((n+1)); BR="backend-drift/$DATE-$n"; done
git -C "$WT" switch -q -C "$BR"
( cd "$WT" && claude -p "$(cat "$P/scripts/drift-review-prompt.md")

Report: $OUT/report.json" \
    --permission-mode acceptEdits \
    --allowedTools "Read,Edit,Write,Grep,Glob,WebFetch,Bash(python3 plugins/learn-toolkit/scripts/check-backends.py*),Bash(bash plugins/learn-toolkit/scripts/lint-skill.sh*),Bash(python3 -m unittest*)" \
    --max-turns 80 > "$OUT/review.md" 2>&1 ) || log "claude review exited non-zero"

if [ -z "$(git -C "$WT" status --porcelain)" ]; then
  log "${prefix}drift found (exit $rc), no change proposed"
  notify "learn-toolkit weekly check: drift (exit $rc) but no fix proposed. Review: $OUT/review.md"; exit 0
fi
git -C "$WT" add -A
git -C "$WT" commit -q -m "chore: backend drift fixes $DATE

_(Claude, on Yotam's behalf)_"
if [ "$DRY_RUN" = 1 ]; then
  log "dry-run: would open PR from $BR ($(git -C "$WT" diff --stat HEAD~1 | tail -1))"
  notify "[dry-run] learn-toolkit weekly check: drift (exit $rc), would open PR $BR"; exit 0
fi
case "$BR" in backend-drift/*) ;; *) log "refusing to push $BR"; exit 1 ;; esac
git -C "$WT" push -q origin "HEAD:refs/heads/$BR"
PR_BODY=$(mktemp "$OUT/pr-body.XXXXXX")
cat > "$PR_BODY" <<'EOF'
_(Claude, on Yotam's behalf)_

Weekly backend drift check report.
EOF
printf '\nExit code: %s\n\n```json\n' "$rc" >> "$PR_BODY"
head -c 20000 "$OUT/report.json" >> "$PR_BODY"
printf '\n```\n\n' >> "$PR_BODY"
tail -c 20000 "$OUT/review.md" >> "$PR_BODY"
printf '\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n' >> "$PR_BODY"
URL=$(cd "$WT" && gh pr create --draft --base main --head "$BR" \
  --title "Backend drift $DATE (Exa/Tavily)" --body-file "$PR_BODY")
log "opened $URL"
notify "learn-toolkit weekly check: drift (exit $rc). Draft PR: $URL"
