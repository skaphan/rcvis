#!/bin/bash
set -e

# Migrations are pre-baked into the image (see Dockerfile).
# Only create the API user at startup. Credentials come from env vars so
# the same values can be supplied to both this rcvis instance and the
# svelte-rcv client that authenticates against it — no more hardcoded
# password drift between the two.
: "${RCVIS_ADMIN_USERNAME:?RCVIS_ADMIN_USERNAME is required}"
: "${RCVIS_ADMIN_PASSWORD:?RCVIS_ADMIN_PASSWORD is required}"

python manage.py shell -c "
import os
from django.contrib.auth import get_user_model
User = get_user_model()
username = os.environ['RCVIS_ADMIN_USERNAME']
password = os.environ['RCVIS_ADMIN_PASSWORD']
if not User.objects.filter(username=username).exists():
    user = User.objects.create_superuser(username, 'admin@rcv-lab.org', password)
    user.userprofile.canUseApi = True
    user.userprofile.save()
    print(f'Created API user {username}')
else:
    print(f'API user {username} already exists')
"

exec "$@"
