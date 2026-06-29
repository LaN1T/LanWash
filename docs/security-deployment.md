# LanWash Pre-Launch Security & Deployment Checklist

This document summarizes the hardening steps and secrets management required before deploying LanWash to a public/production environment. HTTPS/TLS specifics are intentionally excluded per project scope.

## Before First Production Deploy

### 1. Rotate all secrets

Generate strong, unique values for every secret. Do **not** reuse the example/placeholder values from `.env.example`.

- `JWT_SECRET_KEY` — at least 43 url-safe characters
- `JWT_REFRESH_TOKEN_EXPIRE_DAYS` — recommended 7
- `INITIAL_ADMIN_PASSWORD`
- `REDIS_PASSWORD`
- `POSTGRES_PASSWORD`
- `PROMETHEUS_API_TOKEN`
- `GRAFANA_PASSWORD`
- `FCM_ENCRYPTION_KEY`
- Firebase service-account credentials
- Telegram bot token and webhook secret

### 2. Keep secrets out of the repository

The following files must **not** be committed or copied to production hosts inside the project directory:

- `.env`
- `lib/firebase_options.dart`
- `nginx/.htpasswd`
- `nginx/ssl/*.pem`
- `prometheus/web.config.yml`
- `*.db` SQLite files (development/test artifacts)

Store the production `.env` outside the repo, for example:

```bash
/etc/lanwash/.env
```

Run Docker Compose with the external env file:

```bash
docker compose --env-file /etc/lanwash/.env -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 3. Generate Prometheus/Grafana auth files on the host

Example for Prometheus web config:

```bash
python - <<'PY'
import bcrypt
password = input("Prometheus password: ")
hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=12))
print(hash.decode())
PY
```

Write the resulting bcrypt hash to `prometheus/web.config.yml` on the host only.

For Nginx basic auth:

```bash
htpasswd -c nginx/.htpasswd prometheus_user
```

### 4. Clean development artifacts

On the production host:

```bash
rm -f *.db backend/*.db backend/lanwash*.db
```

### 5. Enable App Check in production

Set `APP_CHECK_ENFORCED=true` and ensure the Flutter and mini-app clients send a valid `X-Firebase-AppCheck` token.

### 6. Database backups

Schedule the provided backup script:

```bash
# /etc/cron.d/lanwash-backup
0 3 * * * /opt/lanwash/scripts/backup_postgres.sh >> /var/log/lanwash-backup.log 2>&1
```

Verify backups regularly and test a restore on a non-production database.

### 7. Review exposed endpoints

In production the following are disabled by default:

- `/docs`
- `/redoc`
- `/openapi.json`

The metrics endpoint `/metrics` requires the `PROMETHEUS_API_TOKEN` bearer token.

### 8. Nginx / reverse proxy

- Do not expose the backend port (8000) publicly.
- The default `location /` in the bundled `nginx/nginx.conf` returns 404; landing and app traffic should be served by dedicated server blocks.
- Grafana has its CSP header cleared because it requires inline scripts/styles.

### 9. Monitoring & alerting

- Confirm Prometheus can scrape `/metrics` with the bearer token.
- Set a Grafana admin password that is not the default placeholder.
- Configure Sentry `SENTRY_DSN` for error tracking.

### 10. SSL/TLS

Although out of scope for this audit, replace the self-signed `nginx/ssl/*.pem` files with certificates from a trusted CA (Let’s Encrypt, cert-manager, or your cloud provider) before public launch.

## Post-Deploy

- Run the full backend test suite (`pytest`) after any infra change.
- Run `ruff check .` and `bandit -r .` on the backend.
- Run `flutter test`, `flutter analyze`, and build release artifacts.
- Run `npm run build` and `npm audit` in `telegram-miniapp/`.
- Periodically re-run dependency audits and rotate secrets every 90 days or after any suspected leak.
