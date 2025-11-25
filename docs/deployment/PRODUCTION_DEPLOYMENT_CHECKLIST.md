# Production Deployment Checklist - VeriTrust with Axiam

**Last Updated:** November 25, 2025  
**Target:** veritrustai.net  
**Status:** Pre-deployment checklist

---

## 🎯 Production Environment Specs

### Domain Configuration
- **Production URL:** https://veritrustai.net
- **Axiam API:** https://axiam.io/api
- **Axiam WebSocket:** wss://axiam.io/cable
- **SSL/TLS:** Required (Let's Encrypt or commercial cert)

### Server Requirements
- **Ruby:** 3.2.2 or higher
- **Rails:** 7.1.6
- **Database:** MySQL 8.1+
- **Cache:** Redis 7+
- **Web Server:** Puma (recommended) or Passenger
- **Reverse Proxy:** Nginx or Apache

---

## 📋 Pre-Deployment Checklist

### 1. Axiam Production Credentials ✓

- [ ] Contact Axiam support (support@axiam.io) to register production site
- [ ] Provide domain: `veritrustai.net`
- [ ] Receive production API key
- [ ] Receive production secret key
- [ ] Verify domain is whitelisted in Axiam production database

### 2. Environment Variables ✓

Create `/var/www/app/config/application.yml` with:

```yaml
production:
  # Axiam Configuration
  AXIAM_API_BASE: "https://axiam.io/api"
  AXIAM_API_KEY: "your_production_api_key"
  AXIAM_SECRET_KEY: "your_production_secret_key"
  AXIAM_DOMAIN: "veritrustai.net"
  AXIAM_CABLE_URL: "wss://axiam.io/cable"
  
  # Database
  DB_HOST: "your_production_db_host"
  DB_PORT: 3306
  DB_NAME: "trustid_production"
  DB_USERNAME: "trustid_user"
  DB_PASSWORD: "your_secure_password"
  
  # Redis
  REDIS_URL: "redis://your_redis_host:6379/0"
  
  # Email (SendGrid recommended)
  SENDGRID_SMTP_USERNAME: "apikey"
  SENDGRID_SMTP_PASSWORD: "your_sendgrid_api_key"
  SENDGRID_SMTP_ADDRESS: "smtp.sendgrid.net"
  SENDGRID_SMTP_PORT: 587
  SENDGRID_SMTP_DOMAIN: "veritrustai.net"
  EMAIL_FROM: "noreply@veritrustai.net"
  
  # Application
  SECRET_KEY_BASE: "run: rails secret"
  APP_HOST: "veritrustai.net"
  RAILS_ENV: "production"
  RAILS_SERVE_STATIC_FILES: "true"
  RAILS_LOG_TO_STDOUT: "true"
```

**Security:**
```bash
# Set restrictive permissions
chmod 600 /var/www/app/config/application.yml
chown deploy:deploy /var/www/app/config/application.yml
```

### 3. Database Setup ✓

```bash
# Create production database
RAILS_ENV=production rails db:create

# Run migrations
RAILS_ENV=production rails db:migrate

# Verify schema
RAILS_ENV=production rails db:schema:load
```

**Verify `axiam_uid` column exists:**
```sql
-- In MySQL console
USE trustid_production;
DESCRIBE users;
-- Should show: axiam_uid VARCHAR(255)
```

### 4. Assets Compilation ✓

```bash
# Precompile assets
RAILS_ENV=production rails assets:precompile

# Build Tailwind CSS
RAILS_ENV=production rails tailwindcss:build

# Verify assets exist
ls -la public/assets/
```

### 5. SSL/TLS Certificate ✓

**Option A: Let's Encrypt (Free)**
```bash
# Install certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d veritrustai.net -d www.veritrustai.net

# Auto-renewal (add to crontab)
0 0 * * * certbot renew --quiet
```

**Option B: Commercial Certificate**
- Purchase SSL cert from provider
- Install on web server
- Configure Nginx/Apache for HTTPS

### 6. Web Server Configuration ✓

**Nginx Configuration** (`/etc/nginx/sites-available/veritrustai.net`):

```nginx
upstream puma {
  server unix:///var/www/app/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name veritrustai.net www.veritrustai.net;
  
  # Redirect HTTP to HTTPS
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name veritrustai.net www.veritrustai.net;
  
  root /var/www/app/public;
  
  # SSL Configuration
  ssl_certificate /etc/letsencrypt/live/veritrustai.net/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/veritrustai.net/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;
  
  # WebSocket support for ActionCable
  location /cable {
    proxy_pass http://puma;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
  
  # Application
  location / {
    proxy_pass http://puma;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
  
  # Static assets
  location ~ ^/(assets|packs|images|javascripts|stylesheets|swfs|system)/ {
    gzip_static on;
    expires max;
    add_header Cache-Control public;
  }
  
  # Error pages
  error_page 500 502 503 504 /500.html;
  client_max_body_size 4G;
  keepalive_timeout 10;
}
```

**Enable site:**
```bash
sudo ln -s /etc/nginx/sites-available/veritrustai.net /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Application Server ✓

**Puma Configuration** (`config/puma.rb`):

```ruby
# Production-specific settings
environment ENV.fetch("RAILS_ENV") { "production" }

# Workers and threads
workers ENV.fetch("WEB_CONCURRENCY") { 4 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
threads threads_count, threads_count

# Socket file
bind "unix:///var/www/app/tmp/sockets/puma.sock"

# Logging
stdout_redirect '/var/www/app/log/puma.stdout.log', '/var/www/app/log/puma.stderr.log', true

# Preload app
preload_app!

# Allow puma to be restarted by `rails restart` command
plugin :tmp_restart
```

**Systemd Service** (`/etc/systemd/system/puma-veritrustai.service`):

```ini
[Unit]
Description=Puma HTTP Server for VeriTrust
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/app
ExecStart=/home/deploy/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Enable and start:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable puma-veritrustai
sudo systemctl start puma-veritrustai
sudo systemctl status puma-veritrustai
```

### 8. Security Configuration ✓

- [ ] Set `RAILS_ENV=production`
- [ ] Enable `force_ssl` in production config
- [ ] Configure secure cookies (httponly, secure flags)
- [ ] Setup firewall (allow only 80, 443, SSH)
- [ ] Disable directory listing in Nginx
- [ ] Setup fail2ban for SSH protection
- [ ] Regular security updates (`apt-get update && apt-get upgrade`)

**Production config** (`config/environments/production.rb`):

```ruby
# Force HTTPS
config.force_ssl = true

# Asset host (optional CDN)
# config.asset_host = 'https://cdn.veritrustai.net'

# Logging
config.log_level = :info
config.log_tags = [:request_id]

# Cache store
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }

# Active Job
config.active_job.queue_adapter = :sidekiq  # if using Sidekiq

# Action Mailer
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SENDGRID_SMTP_ADDRESS'],
  port: ENV['SENDGRID_SMTP_PORT'],
  user_name: ENV['SENDGRID_SMTP_USERNAME'],
  password: ENV['SENDGRID_SMTP_PASSWORD'],
  authentication: :plain,
  enable_starttls_auto: true
}
config.action_mailer.default_url_options = { 
  host: 'veritrustai.net', 
  protocol: 'https' 
}
```

### 9. Monitoring & Logging ✓

**Application Monitoring:**
- [ ] Setup error tracking (Sentry, Rollbar, Airbrake)
- [ ] Setup uptime monitoring (UptimeRobot, Pingdom)
- [ ] Configure log rotation (logrotate)
- [ ] Setup performance monitoring (New Relic, Scout APM)

**Sentry Setup (Optional):**
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.environment = Rails.env
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
end
```

### 10. Backup Strategy ✓

**Database Backups:**
```bash
# Daily backup script (/usr/local/bin/backup_veritrustai_db.sh)
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
mysqldump -u trustid_user -p'password' trustid_production \
  | gzip > /backups/veritrustai_db_$DATE.sql.gz

# Keep only last 7 days
find /backups -name "veritrustai_db_*.sql.gz" -mtime +7 -delete

# Crontab entry
0 2 * * * /usr/local/bin/backup_veritrustai_db.sh
```

**File Storage Backups:**
```bash
# Backup uploaded files (Active Storage)
rsync -avz /var/www/app/storage/ /backups/storage/
```

---

## 🧪 Production Testing

### 1. Test Axiam Authentication

```bash
# SSH to production server
ssh deploy@veritrustai.net

# Rails console
cd /var/www/app
RAILS_ENV=production rails console

# Test authentication
token = AxiamApi.authenticated_token
puts token
# Should return JWT token

# Test lookup
result = AxiamApi.lookup_client(email: 'test@example.com')
puts result.inspect
```

### 2. Test Web Application

```
✓ https://veritrustai.net - Homepage loads
✓ https://veritrustai.net/users/sign_in - Login page loads
✓ Email input and "Sign In With Face" button visible
✓ No JavaScript errors in browser console
✓ SSL certificate valid (green padlock)
```

### 3. Test Login Flow

1. Enter valid email
2. Click "Sign In With Face"
3. Verify push notification received on mobile
4. Complete facial scan
5. Verify redirect to dashboard
6. Check logs for errors:
   ```bash
   tail -f /var/www/app/log/production.log
   ```

### 4. Test Error Scenarios

- [ ] Invalid email → "No account found"
- [ ] Non-existent user → Proper error message
- [ ] Network timeout → Graceful error handling
- [ ] Mobile app not registered → Clear error message

---

## 🚨 Rollback Plan

If deployment fails:

```bash
# Stop application
sudo systemctl stop puma-veritrustai

# Restore database from backup
gunzip < /backups/veritrustai_db_YYYYMMDD.sql.gz | \
  mysql -u trustid_user -p trustid_production

# Restore previous code version
cd /var/www/app
git checkout <previous_commit_hash>

# Restore dependencies
bundle install

# Restart application
sudo systemctl start puma-veritrustai
```

---

## 📞 Emergency Contacts

**Axiam Production Issues:**
- Emergency: support@axiam.io
- Check status: https://status.axiam.io (if available)

**VeriTrust Application:**
- Check logs: `tail -f /var/www/app/log/production.log`
- Restart app: `sudo systemctl restart puma-veritrustai`
- Check Nginx: `sudo nginx -t && sudo systemctl status nginx`

---

## ✅ Post-Deployment

- [ ] Monitor logs for 24 hours
- [ ] Test with real users
- [ ] Verify email delivery working
- [ ] Check ActionCable WebSocket connections
- [ ] Monitor error rates (Sentry)
- [ ] Verify SSL certificate auto-renewal
- [ ] Document any issues encountered
- [ ] Update team on deployment status

---

**Deployment Date:** _____________  
**Deployed By:** _____________  
**Sign-off:** _____________

---

**Status: Ready for Production Deployment** ✅
