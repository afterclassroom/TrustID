# Production Deployment Guide - Axiam Web Client

## 📋 Prerequisites

### 1. Server Requirements
- Ubuntu 20.04+ or similar Linux distribution
- Docker & Docker Compose installed
- Nginx installed and configured
- SSL certificate (Let's Encrypt recommended)
- Redis server (for Rails cache and ActionCable)

### 2. Required Environment Variables
Create a `.env.production` file on the server (DO NOT commit to git):

```bash
# Rails
RAILS_ENV=production
SECRET_KEY_BASE=<generate with: rails secret>
RAILS_MASTER_KEY=<copy from config/credentials/production.key>

# Database
DATABASE_NAME=axiam_client_production
DATABASE_PASS=<secure-password>
DATABASE_HOST=db

# Redis (for cache and ActionCable)
REDIS_URL=redis://localhost:6379/1

# Axiam Integration
AXIAM_API_KEY=<your-api-key>
AXIAM_SECRET_KEY=<your-secret-key>
AXIAM_PUBLIC_KEY=<your-public-key>
AXIAM_API_BASE=https://api.axiam.io
AXIAM_WIDGET_URL=https://cdn.axiam.io/widget.js

# Redis credentials for Axiam ActionCable (SERVER-SIDE ONLY)
REDIS_USERNAME=<from-axiam>
REDIS_PASSWORD=<from-axiam>
CHANNEL_PREFIX=<from-axiam>

# Application
CLIENT_URL=webclient.axiam.io
```

---

## 🔐 Security Checklist

### Before Deployment

- [ ] **Credentials secured**
  - `config/credentials/production.key` NOT committed to git
  - `.env.production` NOT committed to git
  - All sensitive values in encrypted credentials or env file

- [ ] **Redis protected**
  - Redis server requires password (set in `redis.conf`)
  - Redis NOT exposed to public internet (bind to 127.0.0.1)
  - Use Redis URL with authentication in production

- [ ] **SSL/TLS enabled**
  - Nginx configured with valid SSL certificate
  - `force_ssl = true` in `config/environments/production.rb`
  - ActionCable uses WSS (not WS) for WebSocket connections

- [ ] **Database secured**
  - Strong database password
  - Database NOT exposed to public internet
  - Regular backups configured

- [ ] **Host authorization**
  - Production hosts added to `config.hosts` in `production.rb`
  - Only allow known domains/IPs

---

## 🚀 Deployment Steps

### Step 1: Prepare Server

```bash
# Install Docker & Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Nginx
sudo apt update
sudo apt install nginx -y

# Install Redis (if not using external Redis)
sudo apt install redis-server -y
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Secure Redis
sudo nano /etc/redis/redis.conf
# Set: requirepass YOUR_STRONG_PASSWORD
# Set: bind 127.0.0.1
sudo systemctl restart redis-server
```

### Step 2: Clone Repository

```bash
cd /var/www
git clone <your-repo-url> axiam-client
cd axiam-client
```

### Step 3: Setup Production Credentials

```bash
# Create production credentials (on your local machine first)
EDITOR="nano" bin/rails credentials:edit --environment production

# Add to config/credentials/production.yml.enc:
# secret_key_base: <run: rails secret>
# redis_username: <from Axiam>
# redis_password: <from Axiam>
# channel_prefix: <from Axiam>
# database_password: <your-db-password>
# Save and exit

# Copy the production.key to server (secure method)
# On local machine:
cat config/credentials/production.key

# On server:
nano config/credentials/production.key
# Paste the key, save
chmod 600 config/credentials/production.key
```

### Step 4: Create Environment File

```bash
# On server
nano .env.production
# Paste all environment variables from Prerequisites section
# Save and exit
chmod 600 .env.production
```

### Step 5: Configure Docker Compose for Production

**IMPORTANT:** Use `docker-compose.production.yml` for production (already in repo).

On the production server, use this command format:

```bash
# Start with production compose file
docker compose -f docker-compose.production.yml up -d --build

# Or create a symlink (one-time setup)
ln -s docker-compose.production.yml docker-compose.yml
docker compose up -d --build
```

The `docker-compose.production.yml` includes:
- ✅ `RAILS_ENV: production` explicitly set
- ✅ DB healthcheck (waits for MySQL before starting Rails)
- ✅ Puma bound to `127.0.0.1:6000` (localhost only)
- ✅ Production credentials mounted read-only
- ✅ Auto-run migrations on startup
- ✅ Auto-precompile assets
- ✅ Restart policy: `unless-stopped`
- ✅ Rails healthcheck endpoint at `/up`

### Step 6: Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/axiam-client
```

Paste this configuration:

```nginx
upstream rails_app {
    server 127.0.0.1:6000;
}

server {
    listen 80;
    server_name webclient.axiam.io;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name webclient.axiam.io;

    ssl_certificate /etc/letsencrypt/live/webclient.axiam.io/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/webclient.axiam.io/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    client_max_body_size 10M;

    location / {
        proxy_pass http://rails_app;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }

    # WebSocket support for ActionCable
    location /cable {
        proxy_pass http://rails_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # Serve static files directly
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        root /var/www/axiam-client/public;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/axiam-client /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Step 7: Get SSL Certificate (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d webclient.axiam.io
# Follow prompts
sudo systemctl reload nginx
```

### Step 8: Build and Start Application

```bash
# Build and start containers with production compose file
docker compose -f docker-compose.production.yml up -d --build

# Check logs
docker compose -f docker-compose.production.yml logs -f web

# Verify RAILS_ENV is production
docker compose -f docker-compose.production.yml exec web bash -c "echo RAILS_ENV=\$RAILS_ENV"
# Should output: RAILS_ENV=production

# Check log file
docker compose -f docker-compose.production.yml exec web ls -la log/
# Should see production.log (NOT staging.log)

# Verify database connection
docker compose -f docker-compose.production.yml exec web bash -c "RAILS_ENV=production bin/rails db:version"

# Run health check
docker compose -f docker-compose.production.yml exec web bash -c "RAILS_ENV=production bin/rails runner script/health_check.rb"

# Verify Rails cache (Redis connection)
docker compose -f docker-compose.production.yml exec web bash -c "RAILS_ENV=production bin/rails runner 'puts Rails.cache.write(\"test\", \"ok\") && Rails.cache.read(\"test\")'"
```

---

## 🧪 Post-Deployment Testing

### 1. Basic Health Check
```bash
curl https://webclient.axiam.io
# Should return 200 OK
```

### 2. Facial Sign-On Flow
- Navigate to https://webclient.axiam.io/facial_sign_on/login
- Enter test email
- Verify push notification sent
- Check browser console: NO redis credentials visible
- Complete facial authentication on device
- Verify auto-login works

### 3. Security Verification (Browser DevTools)

**Network Tab → Response:**
```javascript
// ✅ Should see:
window.SITE_CREDENTIALS = {
  "channel_prefix": "ch_...",
  "server_url": "wss://webclient.axiam.io/cable"
}

// ❌ Should NOT see:
// redis_username, redis_password, verification_token in HTML
```

### 4. ActionCable WebSocket
- Open browser DevTools → Network → WS tab
- Submit login → should see WebSocket connection to `wss://webclient.axiam.io/cable`
- Verify connection upgrades successfully

### 5. Cache Validation (Server-side)
```bash
# Check Redis cache for token (should expire after 5 minutes)
docker exec -it axiam-client-web-1 bash -c "RAILS_ENV=production bin/rails runner 'puts Rails.cache.stats'"

# Monitor Rails logs during login
docker compose logs -f web
```

---

## 🔄 Updates & Maintenance

### Deploy New Code

```bash
# On server
cd /var/www/axiam-client
git pull origin main

# Rebuild and restart with production compose
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d --build

# Or zero-downtime (recommended):
docker compose -f docker-compose.production.yml build web
docker compose -f docker-compose.production.yml up -d --no-deps web
```

### Database Migrations

```bash
# Migrations run automatically on container start
# Or run manually:
docker compose -f docker-compose.production.yml exec web bash -c "RAILS_ENV=production bin/rails db:migrate"
```

### Clear Assets Cache

```bash
docker compose -f docker-compose.production.yml exec web bash -c "RAILS_ENV=production bin/rails assets:clobber"
docker compose -f docker-compose.production.yml exec web bash -c "RAILS_ENV=production bin/rails assets:precompile"
# Then restart to serve new assets
docker compose -f docker-compose.production.yml restart web
```

### View Logs

```bash
# Application logs
docker compose -f docker-compose.production.yml logs -f web

# Or view production.log directly
docker compose -f docker-compose.production.yml exec web tail -f log/production.log

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Redis logs (if running locally)
sudo tail -f /var/log/redis/redis-server.log
```

---

## 🛡️ Security Best Practices

### 1. Token Security
- ✅ Verification tokens are single-use (deleted after subscription)
- ✅ Tokens expire after 5 minutes
- ✅ Server-side validation via Rails.cache
- ✅ CSRF protection on all endpoints

### 2. Credentials Management
- ✅ Never commit `.env.production` or `production.key`
- ✅ Use Rails encrypted credentials for sensitive data
- ✅ Rotate secrets regularly (SECRET_KEY_BASE, database password)

### 3. Network Security
- ✅ Puma bound to localhost only (127.0.0.1:6000)
- ✅ Nginx as SSL terminator (TLS 1.2+)
- ✅ Redis bound to localhost with password
- ✅ Database not exposed to public

### 4. Monitoring
- Set up log rotation (logrotate)
- Monitor failed login attempts
- Track rejected ActionCable subscriptions
- Set up alerts for errors

---

## 🆘 Troubleshooting

### Issue: 504 Gateway Timeout

**Check:**
```bash
# Is Puma running?
docker compose ps

# Database connection?
docker exec -it axiam-client-web-1 bash -c "RAILS_ENV=production bin/rails db:version"

# Nginx upstream?
sudo nginx -t
```

### Issue: ActionCable Connection Rejected

**Check:**
```bash
# Redis connectivity
docker exec -it axiam-client-web-1 bash -c "RAILS_ENV=production bin/rails runner 'puts Redis.new(url: ENV[\"REDIS_URL\"]).ping'"

# Cache working?
docker exec -it axiam-client-web-1 bash -c "RAILS_ENV=production bin/rails runner 'puts Rails.cache.write(\"test\", \"ok\")'"
```

**Logs:**
```bash
docker compose logs -f web | grep FacialSignOnLoginChannel
```

### Issue: Assets Not Loading

**Check:**
```bash
# Precompile assets
docker exec -it axiam-client-web-1 bash -c "RAILS_ENV=production bin/rails assets:precompile"

# Nginx serving static files
ls -la /var/www/axiam-client/public/assets/
```

### Issue: Database Connection Error

**Check:**
```bash
# DB container running?
docker compose ps db

# Credentials correct in .env.production?
cat .env.production | grep DATABASE

# Test connection
docker exec -it axiam-client-db-1 mysql -u root -p
```

---

## 📞 Support

For issues:
1. Check logs: `docker compose logs -f`
2. Verify configuration files
3. Review this deployment guide
4. Contact Axiam support for API/integration issues

---

**Last Updated:** November 3, 2025
