# VeriTrust Axiam Integration - Quick Setup Guide

**Last Updated:** November 25, 2025  
**For:** Development & Production Environments

---

## 🚀 Quick Start

### Step 1: Clone and Navigate to Project

```bash
cd /var/www/app
```

### Step 2: Setup Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit .env file with your credentials
nano .env  # or vim .env
```

### Step 3: Choose Your Environment

#### **For Development (Localhost Docker)**

Update `.env` with:

```bash
RAILS_ENV=development

# Axiam Configuration (Development)
AXIAM_API_BASE=http://localhost:3000
AXIAM_API_KEY=your_dev_api_key_here
AXIAM_SECRET_KEY=your_dev_secret_key_here
AXIAM_DOMAIN=localhost
AXIAM_CABLE_URL=ws://localhost:3000/cable

# Database (Docker MySQL)
DB_HOST=localhost
DB_PORT=3308
DB_NAME=trustid_development
DB_USERNAME=root
DB_PASSWORD=your_password

# Redis
REDIS_URL=redis://localhost:6379/0
```

#### **For Production (veritrustai.net)**

Update `.env` with:

```bash
RAILS_ENV=production

# Axiam Configuration (Production)
AXIAM_API_BASE=https://axiam.io/api
AXIAM_API_KEY=your_production_api_key_here
AXIAM_SECRET_KEY=your_production_secret_key_here
AXIAM_DOMAIN=veritrustai.net
AXIAM_CABLE_URL=wss://axiam.io/cable

# Database (Production MySQL)
DB_HOST=your_production_db_host
DB_PORT=3306
DB_NAME=trustid_production
DB_USERNAME=trustid_user
DB_PASSWORD=your_secure_password

# Redis
REDIS_URL=redis://your_redis_host:6379/0
```

---

## 🔑 Getting Axiam Credentials

### Development Credentials

Contact Axiam support to register your development site:

**Email:** support@axiam.io or developers@axiam.io

**Information to Provide:**
- Environment: Development
- Domain: `localhost`
- Purpose: VeriTrust Facial Sign-On integration testing

**You will receive:**
- `AXIAM_API_KEY` - Development API key
- `AXIAM_SECRET_KEY` - Development secret key

### Production Credentials

Contact Axiam support to register your production site:

**Information to Provide:**
- Environment: Production
- Domain: `veritrustai.net`
- Purpose: VeriTrust Facial Sign-On production deployment

**You will receive:**
- `AXIAM_API_KEY` - Production API key
- `AXIAM_SECRET_KEY` - Production secret key

---

## 🐳 Docker Setup (Development)

### Current Docker Containers

```
CONTAINER ID   NAME                      PORTS
d898af86960e   trustid-web-1            0.0.0.0:3030->3000/tcp
672927f1a131   trustid-mysql-1          0.0.0.0:3308->3306/tcp
84317311945d   axiamai_rails-app-1      0.0.0.0:3000->3000/tcp
61f0db1a1672   redis                    0.0.0.0:6379->6379/tcp
62ed9831b7ca   axiamai_rails-mysql-1    0.0.0.0:3307->3306/tcp
```

### Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| VeriTrust Web | http://localhost:3030 | Your Rails app |
| Axiam API | http://localhost:3000 | Axiam development server |
| VeriTrust MySQL | localhost:3308 | Database for VeriTrust |
| Axiam MySQL | localhost:3307 | Database for Axiam |
| Redis | localhost:6379 | Cache & ActionCable |

### Start Docker Containers

```bash
# Start all containers
docker-compose up -d

# Check status
docker ps

# View logs
docker-compose logs -f trustid-web-1
```

### Verify Axiam API is Running

```bash
# Test Axiam API health
curl http://localhost:3000/up

# Expected response: "ok" or health check JSON
```

---

## ✅ Verify Setup

### 1. Check Environment Variables Loaded

```bash
# Start Rails console
docker exec -it trustid-web-1 rails console

# Or if not using Docker
rails console
```

```ruby
# Check environment variables
puts ENV['AXIAM_API_BASE']
# Should output: http://localhost:3000 (dev) or https://axiam.io/api (prod)

puts ENV['AXIAM_API_KEY']
# Should output: your_api_key (not blank)

puts ENV['AXIAM_DOMAIN']
# Should output: localhost (dev) or veritrustai.net (prod)
```

### 2. Test Axiam Authentication

```ruby
# In Rails console
token = AxiamApi.authenticated_token
puts token

# Expected output: "eyJhbGciOiJIUzI1NiJ9..."
# If you get an error, check your credentials
```

### 3. Test API Endpoints

```ruby
# Test lookup client (requires existing user in Axiam)
result = AxiamApi.lookup_client(email: 'test@example.com')
puts result.inspect

# Expected success:
# {"success"=>true, "data"=>{"client_id"=>"...", "facial_sign_on_enabled"=>true}}

# Expected error (user not found):
# {"success"=>false, "message"=>"Client not found", "code"=>1007}
```

### 4. Test Login Page

**Development:**
```
Open browser: http://localhost:3030/users/sign_in
```

**Production:**
```
Open browser: https://veritrustai.net/users/sign_in
```

**What to check:**
- ✅ Email input field displays
- ✅ "Sign In With Face" button displays
- ✅ Button is disabled until email is entered
- ✅ No JavaScript errors in browser console (F12)

### 5. Test Full Login Flow

1. Enter a valid email address
2. Click "Sign In With Face"
3. Check browser console for:
   ```
   ✅ Connected to ActionCable
   Connected. Waiting for face scan...
   ```
4. Check your mobile app for push notification
5. Complete face scan on mobile app
6. Web page should redirect to dashboard

---

## 🔧 Troubleshooting

### Error: "Authentication failed: HTTP 401"

**Cause:** Invalid API credentials

**Solution:**
1. Verify `AXIAM_API_KEY` and `AXIAM_SECRET_KEY` are correct
2. Contact Axiam support to verify credentials are active
3. Clear Rails cache: `Rails.cache.clear`

### Error: "Client not found" (Code 1007)

**Cause:** User doesn't have Axiam account

**Solution:**
1. User must complete facial signup first
2. Navigate to: http://localhost:3030/facial_signup/new
3. Complete signup process with QR code scan

### Error: "ActionCable not connecting"

**Cause:** Incorrect WebSocket URL or CORS issue

**Solution (Development):**
```bash
# Verify AXIAM_CABLE_URL
echo $AXIAM_CABLE_URL
# Should be: ws://localhost:3000/cable

# Check Axiam server is running
curl http://localhost:3000/up
```

**Solution (Production):**
```bash
# Verify WSS (not WS)
# AXIAM_CABLE_URL=wss://axiam.io/cable

# Check firewall allows WebSocket connections
# Check SSL certificate is valid
```

### Error: "Domain mismatch"

**Cause:** `AXIAM_DOMAIN` doesn't match registered site in Axiam

**Solution:**
1. Verify `AXIAM_DOMAIN` in `.env`:
   - Development: `localhost`
   - Production: `veritrustai.net`
2. Contact Axiam support to verify domain registration
3. Domain must match EXACTLY (no www, no port number)

### Error: "Connection refused" (Development)

**Cause:** Axiam Docker container not running

**Solution:**
```bash
# Check if Axiam container is running
docker ps | grep axiamai

# Start Axiam container
docker start axiamai_rails-app-1

# Or restart all containers
docker-compose restart
```

---

## 📋 Pre-Production Checklist

Before deploying to production:

- [ ] Obtained production Axiam credentials
- [ ] Updated `AXIAM_API_BASE=https://axiam.io/api`
- [ ] Updated `AXIAM_DOMAIN=veritrustai.net`
- [ ] Updated `AXIAM_CABLE_URL=wss://axiam.io/cable`
- [ ] Changed WS to WSS (secure WebSocket)
- [ ] Verified SSL certificate on veritrustai.net
- [ ] Tested authentication with production credentials
- [ ] Tested full login flow with production mobile app
- [ ] Configured production database
- [ ] Configured production Redis
- [ ] Setup monitoring/logging (Sentry, etc.)
- [ ] Verified CORS settings on Axiam production
- [ ] Tested error scenarios (timeout, invalid email, etc.)
- [ ] Configured email service (SendGrid) for signup verification
- [ ] Updated `SECRET_KEY_BASE` for production
- [ ] Reviewed security settings (HTTPS only, secure cookies)

---

## 📞 Support Contacts

**Axiam Support:**
- Email: support@axiam.io
- Technical: developers@axiam.io
- Documentation: https://axiam.io/api/docs (if available)

**VeriTrust Team:**
- Check Rails logs: `tail -f log/development.log`
- Check implementation guide: `AXIAM_FACIAL_SIGNIN_IMPLEMENTATION.md`
- Review error codes in documentation

---

## 🔒 Security Reminders

- ✅ Never commit `.env` file to Git (already in `.gitignore`)
- ✅ Use different credentials for dev/prod
- ✅ Rotate credentials every 6-12 months
- ✅ Keep `AXIAM_SECRET_KEY` secure (server-side only)
- ✅ Use HTTPS/WSS in production
- ✅ Monitor failed login attempts
- ✅ Keep Rails and dependencies updated

---

**Setup Complete! 🎉**

Your VeriTrust application is now ready for Axiam Facial Sign-On integration.

Next: Test the login flow at http://localhost:3030/users/sign_in
