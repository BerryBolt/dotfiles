#!/bin/bash
# Register the open-work job. Its pre-check wakes the agent only when an open
# pull request or unsettled T3 thread needs it. See runbooks/t3-mcp.md.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
hermes-python <<'PY'
from pathlib import Path

from cron.jobs import create_job, list_jobs, update_job

name = 'open-work'
schedule = '*/10 * * * *'
fields = dict(
    prompt='Follow ~/brain/routines/open-work.md for the items below.',
    script='open-work.py',
    deliver='telegram',
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
