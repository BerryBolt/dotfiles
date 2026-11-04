#!/bin/bash
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
cd "$HOME/.hermes/hermes-agent"
.venv/bin/python <<'PY'
import fcntl
from pathlib import Path
from cron.jobs import create_job, list_jobs, update_job

# Serialize registrations without replacing Hermes' own job-store locking.
with (Path.home() / '.hermes/berry-sync-registration.lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    matches = [j for j in list_jobs(include_disabled=True) if j.get('name') == 'dotfiles-berry-sync']
    if len(matches) > 1:
        raise RuntimeError('Duplicate dotfiles-berry-sync jobs; resolve manually')
    fields = dict(script='berry-sync.sh', no_agent=True,
                  deliver='local', workdir=str(Path.home()))
    if not matches:
        create_job(prompt='', schedule='*/5 * * * *', name='dotfiles-berry-sync', **fields)
    else:
        job = matches[0]
        changes = {key: value for key, value in fields.items() if job.get(key) != value}
        if job.get('schedule', {}).get('expr') != '*/5 * * * *':
            changes['schedule'] = '*/5 * * * *'
        if changes and update_job(job['id'], changes) is None:
            raise RuntimeError('Sync job disappeared during registration')
PY
