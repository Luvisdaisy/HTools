#!/bin/bash
# One-shot developer POC. The GUI remains unprivileged; no service is installed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
POC_EXE="$ROOT/dist/KeyboardGuardPOCWorker"
SECONDS_TO_TEST="${1:-30}"
MODE="${2:-run}"
if [[ ! "$SECONDS_TO_TEST" =~ ^([1-9]|[12][0-9]|30)$ ]] || [[ "$MODE" != run && "$MODE" != --inspect ]]; then
    printf 'Usage: bash scripts/run-keyboard-poc.sh [1..30] [--inspect]\n' >&2
    exit 64
fi
if [[ ! -x "$POC_EXE" ]]; then
    printf 'Build first: bash scripts/build-keyboard-poc.sh worker\n' >&2
    exit 1
fi
umask 077
POC_OUTPUT="$ROOT/output/keyboard-poc"
mkdir -p "$POC_OUTPUT"
RUN_DIR="$(mktemp -d "$POC_OUTPUT/admin-run.XXXXXXXX")"
"$POC_EXE" --list > "$RUN_DIR/devices.jsonl"
# Reject ambiguity instead of choosing the first external keyboard without a user choice.
IDS="$(/usr/bin/python3 - "$RUN_DIR/devices.jsonl" <<'PY'
import json
import sys
events = [json.loads(line) for line in open(sys.argv[1])]
devices = [e for e in events if e.get('kind') == 'connected']
internal = [e['device'] for e in devices if e['classification']['role'] == 'builtIn']
external = [e['device'] for e in devices if e['classification']['role'] == 'external']
potential = [e for e in devices if e['device'].get('builtIn') is True and e['classification']['role'] != 'virtual']
if len(internal) != 1 or len(external) != 1 or len(potential) != 1:
    sys.exit('Requires exactly one trusted internal and one external keyboard. Inspect devices.jsonl; use explicit CLI IDs for other topologies.')
print(internal[0]['registryID'], external[0]['registryID'])
print('Internal: ' + internal[0]['product'] + '; external: ' + external[0]['product'], file=sys.stderr)
PY
)"
read -r INTERNAL_ID EXTERNAL_ID <<< "$IDS"
printf 'Target=%s External=%s Duration=%ss\nEvidence: %s\n' "$INTERNAL_ID" "$EXTERNAL_ID" "$SECONDS_TO_TEST" "$RUN_DIR"
if [[ "$MODE" == --inspect ]]; then
    printf 'Inspection only. No sudo, no seize.\n'
    exit 0
fi
if [[ ! -t 0 ]]; then
    printf 'Run interactively in Terminal to confirm physical baseline and enter administrator credentials locally.\n' >&2
    exit 64
fi
printf 'Confirm both physical keyboards work and all keys are released. Type START to run one bounded administrator worker: '
read -r BASELINE_CONFIRMATION
[[ "$BASELINE_CONFIRMATION" == START ]] || exit 1
# Root executes only the fixed, locally built worker. Evidence files and tee run as the current user.
# Do not use exec: the worker monitors its parent, so this script stays alive until it finishes.
if /usr/bin/sudo -- "$POC_EXE" --seize "$INTERNAL_ID" --external "$EXTERNAL_ID" --seconds "$SECONDS_TO_TEST" |
    /usr/bin/tee "$RUN_DIR/worker.jsonl"; then
    /usr/bin/python3 - "$RUN_DIR" <<'PY'
import datetime
import json
import pathlib
import sys
directory = pathlib.Path(sys.argv[1])
events = [json.loads(line) for line in (directory / 'worker.jsonl').read_text().splitlines()]
if not any(e['kind'] == 'seize_result' and e.get('code') == 0 for e in events) or not any(
    e['kind'] == 'release_result' and e.get('code') == 0 for e in events
):
    sys.exit('No successful seize/release pair; physical verification remains pending.')
run_id = events[0]['runID']
questions = [('internal_blocked', '独占期间内置普通键及修饰键被屏蔽'),
             ('external_works', '同一轮独占期间外接实体键盘正常输入'),
             ('trackpad_works', '同一轮独占期间内置触控板移动和点击正常'),
             ('internal_restored', '释放之后内置实体键盘恢复输入')]
with open('/dev/tty', 'r') as terminal_input, open('/dev/tty', 'w') as terminal_output, open(directory / 'observations.jsonl', 'w') as output:
    for kind, question in questions:
        while True:
            terminal_output.write(question + '？[y=确认 n=不符合 u=未验证]: ')
            terminal_output.flush()
            answer = terminal_input.readline().strip().lower()
            if answer in ('y', 'n', 'u'):
                break
            if not answer:
                sys.exit('No observation supplied; remaining checks stay unverified.')
        output.write(json.dumps(dict(timestamp=datetime.datetime.now(datetime.timezone.utc).isoformat(),
            runID=run_id, kind=kind, source='user_observation',
            message={'y': 'confirmed', 'n': 'failed', 'u': 'unverified'}[answer]), ensure_ascii=False) + '\n')
print('Saved API evidence and user observations to ' + str(directory))
PY
else
    printf 'Worker did not complete successfully. Preserve its raw error; do not mark physical verification passed.\n' >&2
    exit 2
fi
