#!/bin/bash
# Registers Hermes' monthly release check: a script job with no model call that
# sends its output to Telegram. See runbooks/update-hermes.md.
set -euo pipefail
cd "$HOME/.hermes/hermes-agent"
venv/bin/python <<'PY'
from cron.jobs import create_job, list_jobs, update_job

name = 'hermes-release-check'
schedule = '0 9 1 * *'
fields = dict(script='hermes-release-check.sh', no_agent=True, deliver='telegram')
matches = [j for j in list_jobs(include_disabled=True) if j.get('name') == name]
if len(matches) > 1:
    raise RuntimeError(f'Duplicate {name} jobs; resolve manually')
if not matches:
    create_job(prompt=None, schedule=schedule, name=name, **fields)
else:
    job = matches[0]
    changes = {key: value for key, value in fields.items() if job.get(key) != value}
    if job.get('schedule', {}).get('expr') != schedule:
        changes['schedule'] = schedule
    if changes and update_job(job['id'], changes) is None:
        raise RuntimeError(f'{name} job disappeared during registration')
PY
