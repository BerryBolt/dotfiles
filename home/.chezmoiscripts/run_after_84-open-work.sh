#!/bin/bash
# Register the open-work job. Its pre-check wakes the agent when GitHub work
# or an unsettled T3 thread needs attention. See runbooks/t3-mcp.md.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
hermes-python <<'PY'
from pathlib import Path
import re

from dotenv import dotenv_values

from cron.jobs import create_job, list_jobs, update_job

env = dotenv_values(Path.home() / '.hermes/.env', interpolate=False)
topic = env.get('OPEN_WORK_TELEGRAM_TOPIC_ID', '')
deliver = 'telegram'
if topic:
    owner = env.get('TELEGRAM_HOME_CHANNEL', '')
    if not re.fullmatch(r'[1-9][0-9]*', topic) or not re.fullmatch(r'-?[1-9][0-9]*', owner):
        raise RuntimeError('Open-work topic delivery requires a positive topic ID and a numeric home chat')
    deliver = f'telegram:{owner}:{topic}'

name = 'open-work'
schedule = '*/10 * * * *'
fields = dict(
    prompt='Follow ~/brain/routines/open-work.md for the items below.',
    script='open-work.py',
    deliver=deliver,
    workdir=str(Path.home() / 'brain'),
    enabled_toolsets=['terminal', 'file', 'skills', 'mcp-t3-code'],
    # Each run sees its last report, so unchanged blockers aren't repeated.
    context_from=['self'],
)
matches = [j for j in list_jobs(include_disabled=True) if j.get('name') == name]
if len(matches) > 1:
    raise RuntimeError(f'Duplicate {name} jobs; resolve manually')
if not matches:
    create_job(schedule=schedule, name=name, **fields)
else:
    job = matches[0]
    changes = {key: value for key, value in fields.items() if job.get(key) != value}
    if job.get('schedule', {}).get('expr') != schedule:
        changes['schedule'] = schedule
    if changes and update_job(job['id'], changes) is None:
        raise RuntimeError(f'{name} job disappeared during registration')
PY
