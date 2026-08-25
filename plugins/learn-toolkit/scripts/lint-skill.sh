#!/usr/bin/env bash
# lint-skill.sh — mechanical consistency lint for the learn-toolkit "learn" skill.
#
# Catches the class of defect a careful review found by hand: a variable used
# but never defined, a body command the frontmatter's allowed-tools does not
# permit, a stated count that drifts from the list beside it, a tool name in
# prose that .mcp.json does not actually enable, a deprecated tool mentioned
# without a warning, a references/*.md pointer to a file that does not exist,
# and phase headings that go backwards. All seven checks derive everything
# from the files at runtime — nothing here is a hardcoded snapshot of today's
# content.
#
# Exit 0 on a clean run, 1 if any check finds something. Run from anywhere;
# paths are resolved relative to this script's own location.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL_MD="${PLUGIN_ROOT}/skills/learn/SKILL.md"
SKILL_DIR="${PLUGIN_ROOT}/skills/learn"
MCP_JSON="${PLUGIN_ROOT}/.mcp.json"
README_MD="${PLUGIN_ROOT}/README.md"
SETUP_GUIDE="${PLUGIN_ROOT}/references/setup-guide.md"

FINDINGS=0
PASSED=0
TOTAL_CHECKS=7

fail_line() {
  local check="$1" detail="$2"
  echo "FAIL: ${check} — ${detail}"
  FINDINGS=$((FINDINGS + 1))
}

ok_line() {
  local check="$1"
  echo "OK: ${check}"
  PASSED=$((PASSED + 1))
}

# Runs one check: given its name and its (possibly multi-line, possibly
# empty) finding output, emits OK/FAIL lines and updates the counters.
report() {
  local name="$1" output="$2"
  if [[ -z "${output}" ]]; then
    ok_line "${name}"
    return
  fi
  local had_line=0
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    fail_line "${name}" "${line}"
    had_line=1
  done <<< "${output}"
  # Defensive: if output was non-empty but every line was blank, still pass.
  if [[ "${had_line}" -eq 0 ]]; then
    ok_line "${name}"
  fi
}

if [[ ! -f "${SKILL_MD}" ]]; then
  echo "FAIL: setup — SKILL.md not found at ${SKILL_MD}"
  echo "lint-skill: 0 checks passed"
  exit 1
fi

# --------------------------------------------------------------------------
# Check 1: undefined variable references in SKILL.md
# --------------------------------------------------------------------------
check1_undefined_vars() {
  python3 - "${SKILL_MD}" "HOME,ARGUMENTS,CLAUDE_SKILL_DIR,CLAUDE_PLUGIN_ROOT,TAVILY_API_KEY,EXA_API_KEY,SHELL" <<'PYEOF'
import re
import sys

skill_md, whitelist_csv = sys.argv[1], sys.argv[2]
whitelist = set(whitelist_csv.split(","))

text = open(skill_md, encoding="utf-8").read()
lines = text.splitlines()

var_re = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?')

# Definition-verb vocabulary: prose in SKILL.md defines a variable with any of
# these verbs, not just an `=` assignment or "is the". Word-bounded stems so
# "set" doesn't also match "offset", "subset", "settings", or "asset".
DEFINITION_VERB_RE = re.compile(
    r'\b(?:determin\w*|resolv\w*|deriv\w*|comput\w*|defin\w*|extract\w*|set(?:s|ting)?)\b',
    re.IGNORECASE,
)

first_use = {}
for i, line in enumerate(lines, 1):
    for m in var_re.finditer(line):
        name = m.group(1)
        first_use.setdefault(name, i)

for name in sorted(first_use):
    if name in whitelist:
        continue
    defined = False
    assign_re = re.compile(r'\b' + re.escape(name) + r'\s*=')
    ref_re = re.compile(r'\$\{?' + re.escape(name) + r'\}?')
    for line in lines:
        if assign_re.search(line):
            defined = True
            break
        if ref_re.search(line):
            if ('=' in line or re.search(r'is the', line, re.I)
                    or DEFINITION_VERB_RE.search(line)):
                defined = True
                break
    if not defined:
        print(f"${{{name}}} used (first on line {first_use[name]}) but never assigned or "
              f"derived anywhere in SKILL.md")
PYEOF
}

# --------------------------------------------------------------------------
# Check 2: body commands vs. allowed-tools
# --------------------------------------------------------------------------
check2_allowed_tools() {
  python3 - "${SKILL_MD}" <<'PYEOF'
import re
import shlex
import sys

skill_md = sys.argv[1]
text = open(skill_md, encoding="utf-8").read()
lines = text.splitlines()

# --- Parse allowed-tools out of the YAML frontmatter -----------------------
fm_end = None
if lines and lines[0].strip() == "---":
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            fm_end = i
            break
frontmatter_lines = lines[1:fm_end] if fm_end else []

allowed_raw = None
allowed_start = None
for i, line in enumerate(frontmatter_lines):
    m = re.match(r'^allowed-tools:\s*(.*)$', line)
    if m:
        allowed_raw = m.group(1)
        allowed_start = i
        break

if allowed_start is not None:
    j = allowed_start + 1
    while j < len(frontmatter_lines):
        nxt = frontmatter_lines[j]
        if re.match(r'^\S+:', nxt) or nxt.strip() == "":
            break
        allowed_raw += " " + nxt.strip()
        j += 1

allowed_raw = allowed_raw or ""
entries = [e.strip() for e in re.split(r',(?![^(]*\))', allowed_raw) if e.strip()]

bash_words = set()
bash_bare = False
for e in entries:
    if e == "Bash":
        bash_bare = True
        continue
    m = re.match(r'^Bash\(\s*([A-Za-z0-9_.\-]+)', e)
    if m:
        bash_words.add(m.group(1))

def command_allowed(word):
    if bash_bare:
        return True
    return word in bash_words

CONTROL_WORDS = {
    "if", "then", "else", "elif", "fi", "for", "while", "until", "do",
    "done", "case", "esac", "function", "{", "}", "[", "[[", "]]",
}

def split_segments(line):
    segments = []
    current = []
    in_squote = False
    in_dquote = False
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        two = line[i:i + 2]
        if c == "'" and not in_dquote:
            in_squote = not in_squote
            current.append(c)
        elif c == '"' and not in_squote:
            in_dquote = not in_dquote
            current.append(c)
        elif not in_squote and not in_dquote and two in ("&&", "||"):
            segments.append("".join(current))
            current = []
            i += 1
        elif not in_squote and not in_dquote and c in (";", "|"):
            segments.append("".join(current))
            current = []
        else:
            current.append(c)
        i += 1
    segments.append("".join(current))
    return [s.strip() for s in segments if s.strip()]

SLASH_COMMAND_RE = re.compile(r'^/[A-Za-z0-9_-]+(?::[A-Za-z0-9_-]+)*$')
ALL_CAPS_RE = re.compile(r'^[A-Z][A-Z0-9_]*$')

def looks_like_shell_word(word):
    """Filters out tokens that are structurally not a shell command name:
    a Claude Code slash-command reference, a CLI flag, an ALL_CAPS
    pseudo-variable (real Unix commands are lowercase), or a bare
    key=value / key=<placeholder> expression."""
    if not word:
        return False
    if word.startswith("-"):
        return False
    if SLASH_COMMAND_RE.match(word):
        return False
    if ALL_CAPS_RE.match(word):
        return False
    if "=" in word:
        return False
    return True

def first_command_word(segment):
    seg = segment.strip()
    # Strip leading env-style assignments: FOO=bar BAZ=qux realcmd ...
    while True:
        m = re.match(r'^[A-Za-z_][A-Za-z0-9_]*=\S*\s+(.*)$', seg)
        if not m:
            break
        seg = m.group(1).strip()
    if not seg or seg.startswith("#"):
        return None
    try:
        tokens = shlex.split(seg)
    except ValueError:
        tokens = seg.split()
    if not tokens:
        return None
    word = tokens[0]
    if word in CONTROL_WORDS:
        return None
    if word.startswith("$"):
        return None
    if not looks_like_shell_word(word):
        return None
    return word

findings = []

# --- Fenced ```bash blocks ---------------------------------------------
in_fence = False
fence_skip = False
fence_start_line = None
for i, line in enumerate(lines):
    stripped = line.strip()
    if not in_fence and stripped.startswith("```bash"):
        in_fence = True
        fence_start_line = i
        context = "\n".join(lines[max(0, i - 5):i]).lower()
        fence_skip = "the user" in context
        continue
    if in_fence and stripped.startswith("```"):
        in_fence = False
        fence_skip = False
        continue
    if in_fence:
        if fence_skip:
            continue
        raw = line
        if raw.strip().startswith("! "):
            continue
        if raw.strip().startswith("#"):
            continue
        for seg in split_segments(raw):
            word = first_command_word(seg)
            if word and not command_allowed(word):
                findings.append(
                    f"line {i + 1}: body ```bash block runs `{word}` "
                    f"(from `{seg.strip()[:60]}`) but allowed-tools does not permit it"
                )

# --- Inline backticked commands that begin a line or follow Run/run -------
in_fence = False
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("```"):
        in_fence = not in_fence
        continue
    if in_fence:
        continue
    if "the user" in line.lower():
        continue

    # (content, requires_multi_token) — a bare backtick span leading a line is
    # only a command instruction (not a defined term, flag value, or literal)
    # when it has command-like shape: verb plus argument(s). An explicit
    # "Run `...`" / "run `...`" is a strong enough signal on its own, even
    # for a single-word command.
    candidates = []
    lead = re.match(r'^(?:[-*]\s+|\d+\.\s+)?`([^`]+)`', stripped)
    if lead:
        candidates.append((lead.group(1), True))
    for m in re.finditer(r'\b[Rr]un\s+`([^`]+)`', line):
        candidates.append((m.group(1), False))

    for content, requires_multi_token in candidates:
        c = content.strip()
        if not c or c.startswith("!"):
            continue
        try:
            tokens = shlex.split(c)
        except ValueError:
            tokens = c.split()
        if not tokens:
            continue
        if requires_multi_token and len(tokens) < 2:
            continue
        word = tokens[0]
        if word in CONTROL_WORDS or word.startswith("$"):
            continue
        if not looks_like_shell_word(word):
            continue
        if not command_allowed(word):
            findings.append(
                f"line {i + 1}: inline command `{c}` runs `{word}` but "
                f"allowed-tools does not permit it"
            )

for f in findings:
    print(f)
PYEOF
}

# --------------------------------------------------------------------------
# Check 3: count-versus-enumeration drift
# --------------------------------------------------------------------------
check3_count_drift() {
  python3 - "${SKILL_MD}" <<'PYEOF'
import re
import sys

skill_md = sys.argv[1]
text = open(skill_md, encoding="utf-8").read()
lines = text.splitlines()

NUMBER_WORDS = {
    "two": 2, "three": 3, "four": 4, "five": 5, "six": 6,
    "seven": 7, "eight": 8, "nine": 9, "ten": 10,
}
phrase_re = re.compile(
    r'\b(two|three|four|five|six|seven|eight|nine|ten)\b\s+([A-Za-z][A-Za-z\-]*s)\b',
    re.IGNORECASE,
)

def count_json_object(window_text, start_pos):
    brace = window_text.find("{", start_pos)
    if brace == -1:
        return None
    depth = 0
    end = None
    for idx in range(brace, len(window_text)):
        ch = window_text[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = idx
                break
    if end is None:
        return None
    obj_text = window_text[brace:end + 1]
    # Only count keys at the outermost level of this object.
    inner_depth = 0
    keys = 0
    key_re = re.compile(r'"[A-Za-z0-9_]+"\s*:')
    idx = 0
    while idx < len(obj_text):
        ch = obj_text[idx]
        if ch == "{" or ch == "[":
            inner_depth += 1
        elif ch == "}" or ch == "]":
            inner_depth -= 1
        elif inner_depth == 1:
            m = key_re.match(obj_text, idx)
            if m:
                keys += 1
                idx = m.end()
                continue
        idx += 1
    return keys if keys else None

def count_markdown_list(window_lines):
    # A single bullet is not an "enumeration" worth comparing a count
    # against — require at least two consecutive list items, and the list
    # must start within the first couple of lines after the phrase.
    bullet_re = re.compile(r'^\s*(?:[-*]\s+|\d+\.\s+)')
    for offset in range(min(3, len(window_lines))):
        if bullet_re.match(window_lines[offset]):
            count = 0
            for ln in window_lines[offset:]:
                if bullet_re.match(ln):
                    count += 1
                else:
                    break
            return count if count >= 2 else None
    return None

SENTENCE_END_RE = re.compile(r'[.;](?:\s|$)')

def clause_after(full_text, start_pos, max_chars=600):
    """The text right after a phrase, up to the first sentence-ending
    punctuation or blank line — i.e. the same sentence/clause, so an
    enumeration is only compared against the list that actually goes with
    the phrase and not some unrelated list later in the same paragraph.
    A period is only treated as a sentence end when followed by whitespace
    (or end of string), so it doesn't false-trigger on a filename like
    `fetch.sh` inside the very list being counted."""
    window = full_text[start_pos:start_pos + max_chars]
    stops = []
    m = SENTENCE_END_RE.search(window)
    if m:
        stops.append(m.start())
    blank = window.find("\n\n")
    if blank != -1:
        stops.append(blank)
    end = min(stops) if stops else len(window)
    return window[:end + 1]

def count_comma_list(clause):
    # Try backtick-quoted items, then **bold** items, within the clause
    # immediately following the phrase; then a plain comma-separated run
    # of words after a colon in that same clause.
    for pattern in (r'`[^`]+`', r'\*\*[^*]+\*\*'):
        spans = re.findall(pattern, clause)
        if len(spans) >= 2:
            return len(spans)
    if ":" in clause:
        tail = clause.split(":", 1)[1]
        items = [it.strip() for it in tail.split(",") if it.strip()]
        if len(items) >= 2:
            return len(items)
    return None

findings = []
for m in phrase_re.finditer(text):
    number_word = m.group(1).lower()
    noun = m.group(2)
    claimed = NUMBER_WORDS[number_word]
    line_no = text.count("\n", 0, m.start()) + 1
    line_idx = line_no - 1

    clause = clause_after(text, m.end())
    window_lines = lines[line_idx:line_idx + 16]

    actual = count_json_object(clause, 0)
    source = "JSON object"
    if actual is None:
        actual = count_markdown_list(window_lines)
        source = "markdown list"
    if actual is None:
        actual = count_comma_list(clause)
        source = "comma list"

    if actual is not None and actual != claimed:
        findings.append(
            f"line {line_no}: says \"{number_word} {noun}\" ({claimed}) but the "
            f"nearby {source} has {actual} item(s)"
        )

for f in findings:
    print(f)
PYEOF
}

# --------------------------------------------------------------------------
# Check 4: cross-file *_exa tool-name agreement with .mcp.json
# --------------------------------------------------------------------------
check4_exa_agreement() {
  # Pass the domains directory itself (rather than a pre-expanded bash
  # array of its files) so an empty or missing directory needs no special
  # casing here — Python globs it directly.
  python3 - "${MCP_JSON}" "${SKILL_MD}" "${README_MD}" "${SETUP_GUIDE}" "${SKILL_DIR}/references/domains" <<'PYEOF'
import glob
import json
import os
import re
import sys
from urllib.parse import urlparse, parse_qs

mcp_json = sys.argv[1]
prose_files = list(sys.argv[2:-1])
domains_dir = sys.argv[-1]
if os.path.isdir(domains_dir):
    prose_files += sorted(glob.glob(os.path.join(domains_dir, "*.md")))

try:
    with open(mcp_json, encoding="utf-8") as fh:
        data = json.load(fh)
except (OSError, json.JSONDecodeError) as exc:
    print(f".mcp.json could not be parsed: {exc}")
    sys.exit(0)

exa_url = None
for _, server in data.get("mcpServers", {}).items():
    url = server.get("url", "")
    if "exa" in url.lower():
        exa_url = url
        break

allowed = set()
if exa_url:
    qs = parse_qs(urlparse(exa_url).query)
    tools_param = qs.get("tools", [""])[0]
    allowed = {t.strip() for t in tools_param.split(",") if t.strip()}

tool_re = re.compile(r'(?:mcp__exa__)?([a-z][a-z0-9_]*_exa)\b')
PROHIBITION_RE = re.compile(r'\b(?:never|no\s+longer|not|deprecated|removed)\b', re.IGNORECASE)


def reflow_paragraphs(lines):
    """Join consecutive non-blank lines into logical paragraphs, the way a
    markdown renderer would wrap them back into prose. A blank line, a
    heading, a list-item start, or a fence boundary ends the current
    paragraph. Inside a fenced code block, each line stands alone (no
    joining) so unrelated code lines never get pulled into prose. Returns a
    list of paragraphs, each a list of (line_no, line_text)."""
    bullet_re = re.compile(r'^\s*(?:[-*+]\s+|\d+\.\s+)')
    heading_re = re.compile(r'^\s*#')
    fence_re = re.compile(r'^\s*```')
    paragraphs = []
    current = []
    in_fence = False
    for i, line in enumerate(lines, 1):
        if fence_re.match(line):
            if current:
                paragraphs.append(current)
                current = []
            in_fence = not in_fence
            continue
        if in_fence:
            if current:
                paragraphs.append(current)
                current = []
            if line.strip():
                paragraphs.append([(i, line)])
            continue
        if not line.strip():
            if current:
                paragraphs.append(current)
                current = []
            continue
        if heading_re.match(line) or bullet_re.match(line):
            if current:
                paragraphs.append(current)
                current = []
            current.append((i, line))
            continue
        current.append((i, line))
    if current:
        paragraphs.append(current)
    return paragraphs


mentioned = {}
for path in prose_files:
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        continue
    lines = text.splitlines()
    for para in reflow_paragraphs(lines):
        para_text = " ".join(t for _, t in para)
        for m in tool_re.finditer(para_text):
            name = m.group(1)
            # A prohibition cue appearing earlier in the same paragraph than
            # this mention means the paragraph is warning against the tool,
            # not presenting it as something in use — so it doesn't need to
            # be enabled in .mcp.json. A cue that comes AFTER the mention (or
            # is absent) leaves the mention standing as "in use".
            preceding = para_text[:m.start()]
            if PROHIBITION_RE.search(preceding):
                continue
            mentioned.setdefault(name, path)

for name in sorted(mentioned):
    if name not in allowed:
        print(f"`{name}` referenced in {mentioned[name]} but not present in .mcp.json's exa tools= list")
PYEOF
}

# --------------------------------------------------------------------------
# Check 5: deprecated tool names mentioned without a prohibition word
# --------------------------------------------------------------------------
check5_deprecated_tools() {
  python3 - "${PLUGIN_ROOT}" "$(basename "${BASH_SOURCE[0]}")" <<'PYEOF'
import os
import re
import sys

root, self_name = sys.argv[1], sys.argv[2]

TOOLS = ("crawling_exa", "deep_researcher_start", "deep_researcher_check")
PROHIBITION_RE = re.compile(r'\b(?:never|no\s+longer|not|deprecated|removed)\b', re.IGNORECASE)


def reflow_paragraphs(lines):
    """Same reflow used by the exa-tool-agreement check: join consecutive
    non-blank lines into logical paragraphs so a prohibition word that
    markdown wrapped onto the previous or next line is still seen as part of
    the same sentence. A blank line, a heading, a list-item start, or a
    fence boundary ends a paragraph; inside a fence, each line stands alone."""
    bullet_re = re.compile(r'^\s*(?:[-*+]\s+|\d+\.\s+)')
    heading_re = re.compile(r'^\s*#')
    fence_re = re.compile(r'^\s*```')
    paragraphs = []
    current = []
    in_fence = False
    for i, line in enumerate(lines, 1):
        if fence_re.match(line):
            if current:
                paragraphs.append(current)
                current = []
            in_fence = not in_fence
            continue
        if in_fence:
            if current:
                paragraphs.append(current)
                current = []
            if line.strip():
                paragraphs.append([(i, line)])
            continue
        if not line.strip():
            if current:
                paragraphs.append(current)
                current = []
            continue
        if heading_re.match(line) or bullet_re.match(line):
            if current:
                paragraphs.append(current)
                current = []
            current.append((i, line))
            continue
        current.append((i, line))
    if current:
        paragraphs.append(current)
    return paragraphs


findings = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d != ".git"]
    for fname in sorted(filenames):
        if fname == self_name:
            continue
        full = os.path.join(dirpath, fname)
        try:
            with open(full, encoding="utf-8") as fh:
                text = fh.read()
        except (OSError, UnicodeDecodeError):
            continue
        if not any(tool in text for tool in TOOLS):
            continue
        lines = text.splitlines()
        is_md = fname.endswith(".md")
        line_to_para = {}
        if is_md:
            for para in reflow_paragraphs(lines):
                para_text = " ".join(t for _, t in para)
                for ln, _ in para:
                    line_to_para[ln] = para_text
        for tool in TOOLS:
            for i, line in enumerate(lines, 1):
                if tool not in line:
                    continue
                scope = line_to_para.get(i, line) if is_md else line
                if not PROHIBITION_RE.search(scope):
                    findings.append(
                        f"{full}:{i}: bare mention of `{tool}` with no prohibition "
                        f"wording (never/not/no longer/deprecated/removed) in "
                        f"{'its paragraph' if is_md else 'that line'}"
                    )

for f in findings:
    print(f)
PYEOF
}

# --------------------------------------------------------------------------
# Check 6: referenced files exist
# --------------------------------------------------------------------------
check6_references_exist() {
  python3 - "${SKILL_MD}" "${SKILL_DIR}" <<'PYEOF'
import os
import re
import sys

skill_md, base = sys.argv[1], sys.argv[2]
text = open(skill_md, encoding="utf-8").read()

paths = sorted(set(re.findall(r'references/[A-Za-z0-9_\-/]+\.md', text)))
for p in paths:
    full = os.path.join(base, p)
    if not os.path.isfile(full):
        print(f"`{p}` referenced in SKILL.md but no such file at {full}")
PYEOF
}

# --------------------------------------------------------------------------
# Check 7: phase numbering is non-decreasing
# --------------------------------------------------------------------------
check7_phase_order() {
  python3 - "${SKILL_MD}" <<'PYEOF'
import re
import sys

skill_md = sys.argv[1]
text = open(skill_md, encoding="utf-8").read()

heading_re = re.compile(
    r'^###\s*Phase\s+([0-9]+(?:\.[0-9]+)?)(?:-([0-9]+(?:\.[0-9]+)?))?',
    re.MULTILINE,
)

phases = []
for m in heading_re.finditer(text):
    start = float(m.group(1))
    end = float(m.group(2)) if m.group(2) else start
    label = m.group(0).replace("###", "").strip()
    line_no = text.count("\n", 0, m.start()) + 1
    phases.append((start, end, label, line_no))

findings = []
last_end = float("-inf")
seen_labels = set()
for start, end, label, line_no in phases:
    if label in seen_labels:
        findings.append(f"line {line_no}: duplicate heading \"{label}\"")
    seen_labels.add(label)
    if start < last_end:
        findings.append(
            f"line {line_no}: \"{label}\" (start {start}) appears after a later "
            f"phase value {last_end}"
        )
    else:
        last_end = max(last_end, end)

for f in findings:
    print(f)
PYEOF
}

# --------------------------------------------------------------------------
# Run all checks
# --------------------------------------------------------------------------
report "undefined-vars" "$(check1_undefined_vars)"
report "allowed-tools" "$(check2_allowed_tools)"
report "count-drift" "$(check3_count_drift)"
report "exa-tool-agreement" "$(check4_exa_agreement)"
report "deprecated-tools" "$(check5_deprecated_tools)"
report "references-exist" "$(check6_references_exist)"
report "phase-order" "$(check7_phase_order)"

if [[ "${FINDINGS}" -gt 0 ]]; then
  echo "lint-skill: ${PASSED}/${TOTAL_CHECKS} checks passed, ${FINDINGS} finding(s)"
  exit 1
fi

echo "lint-skill: ${PASSED}/${TOTAL_CHECKS} checks passed"
exit 0
