#!/bin/bash
set -e

# Migrations are pre-baked into the image (see Dockerfile).
# Only create the API user at startup.
python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='skaphan').exists():
    user = User.objects.create_superuser('skaphan', 'sjk@kaphan.org', 'rcvisacc0unt')
    user.userprofile.canUseApi = True
    user.userprofile.save()
    print('Created API user skaphan')
else:
    print('API user skaphan already exists')
"

exec "$@"
