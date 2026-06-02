#!/bin/bash
set -e

# Migrations are pre-baked into the image (see Dockerfile).
# Only create the API user at startup. Credentials come from env vars so
# the same values can be supplied to both this rcvis instance and the
# svelte-rcv client that authenticates against it — no more hardcoded
# password drift between the two.
: "${RCVIS_ADMIN_USERNAME:?RCVIS_ADMIN_USERNAME is required}"
: "${RCVIS_ADMIN_PASSWORD:?RCVIS_ADMIN_PASSWORD is required}"

# Per-boot setup. Both steps run in a single `manage.py shell` invocation
# so Django's startup cost is paid once (matters for cold starts):
#
#   1. Create the API user (credentials from env, shared with the
#      svelte-rcv client that authenticates against this instance).
#
#   2. Set the Django Site domain to the host the BROWSER uses to load
#      visualizations. This keeps the server-side render cache fresh: the
#      cache-purge on update (_purge_django_cache) reconstructs cache keys
#      per-host. Browser iframes load from RCVIS_HOST_ALIAS (e.g.
#      rcvis.rcv-lab.org) while our server-to-server PATCH arrives over
#      RCVIS_HOST (the .run.app URL), so without the Site domain pointing
#      at the browser host the purge targets the wrong key and stale
#      renders persist. Falls back to RCVIS_HOST when no alias is set
#      (dev, where browser and server share one host).
#
# The DB is ephemeral (baked SQLite), so both run on every boot.
python manage.py shell -c "
import os
from django.contrib.auth import get_user_model
from django.contrib.sites.models import Site

username = os.environ['RCVIS_ADMIN_USERNAME']
password = os.environ['RCVIS_ADMIN_PASSWORD']
User = get_user_model()
if not User.objects.filter(username=username).exists():
    user = User.objects.create_superuser(username, 'admin@rcv-lab.org', password)
    user.userprofile.canUseApi = True
    user.userprofile.save()
    print(f'Created API user {username}')
else:
    print(f'API user {username} already exists')

host = os.environ.get('RCVIS_HOST_ALIAS') or os.environ['RCVIS_HOST']
Site.objects.update_or_create(id=1, defaults={'domain': host, 'name': host})
print(f'Set Site domain to {host}')
"

exec "$@"
