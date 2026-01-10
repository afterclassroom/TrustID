# JWT Authentication Deployment Checklist

## 📋 Pre-Deployment Checklist

### 1. Code Review ✅

- [x] AuthController created with JWT token endpoint
- [x] AxiamApi service updated with get_jwt_token method
- [x] ApplicationCable::Connection updated for JWT verification
- [x] JwtRevocationService created for token management
- [x] FacialSignOnLoginChannel updated with JWT validation
- [x] FacialSignOnDeviceChannel updated with JWT validation
- [x] All views updated to use JWT tokens:
  - [x] devise/sessions/new.html.erb (login)
  - [x] facial_signup/show_qr.html.erb (signup)
  - [x] devise/registrations/enable_facial_sign_on.html.erb
- [x] Routes updated with /auth/axiam-token endpoint
- [x] Gemfile updated with jwt gem
- [x] Configuration files updated

### 2. Dependencies Installation

```bash
# Navigate to app directory
cd /var/www/app

# Install JWT gem and dependencies
bundle install

# Expected output should include:
# Installing jwt x.x.x
```

**Status:** ⏳ Pending

### 3. Environment Configuration

Review and update `config/application.yml`:

```yaml
# Development (current)
AXIAM_API_KEY: "97dd9b1914cd4b0902130f5c1cbee445"
AXIAM_SECRET_KEY: "c2328bdbdba3b339a10c1492c77eee950c8442d41655c48d15564595eb919b29"
AXIAM_API_BASE: "http://axiamai_rails-app-1:3000"
AXIAM_CABLE_URL: "ws://localhost:3000/cable"
REDIS_URL: "redis://localhost:6379/0"

# Production (to be configured)
# AXIAM_API_KEY: "your_production_api_key"
# AXIAM_SECRET_KEY: "your_production_secret_key"
# AXIAM_API_BASE: "https://axiam.io"
# AXIAM_CABLE_URL: "wss://axiam.io/cable"
# REDIS_URL: "redis://your-redis-server:6379/0"
```

**Status:** ⏳ Pending

### 4. Redis Verification

```bash
# Check if Redis is running
redis-cli ping
# Expected: PONG

# Check Redis connection from Rails
rails runner "puts Redis.new(url: ENV['REDIS_URL']).ping"
# Expected: PONG
```

**Status:** ⏳ Pending

---

## 🚀 Deployment Steps

### Step 1: Development Environment Testing

```bash
# 1. Install dependencies
cd /var/www/app
bundle install

# 2. Restart development server
docker-compose restart

# 3. Check logs for startup errors
docker logs -f axiam_client_app-veritrust_1 | head -50

# 4. Test JWT endpoint
curl http://localhost:8000/auth/axiam-token

# Expected response:
# {
#   "success": true,
#   "token": "eyJ...",
#   "expires_in": 7200,
#   "expires_at": "..."
# }
```

### Step 2: Functional Testing

**Test Facial Login:**

1. Open: http://localhost:8000/users/sign_in
2. Enter email address
3. Click "Sign In With Face"
4. Open browser console (F12)
5. Verify logs show:
   - ✅ JWT token fetched successfully
   - ✅ WebSocket connected with JWT
   - ✅ Channel subscribed with jwt_authenticated: true

**Test Facial Signup:**

1. Open: http://localhost:8000/users/sign_up
2. Fill signup form
3. Submit to QR code page
4. Open browser console (F12)
5. Verify logs show:
   - ✅ JWT token fetched
   - ✅ WebSocket authenticated
   - ✅ QR code displayed

**Check Server Logs:**

```bash
# Watch ActionCable logs
docker logs -f axiam_client_app-veritrust_1 | grep ActionCable

# Expected logs:
# [ActionCable] ✅ JWT authentication successful for site_id=...
# [FacialSignOnLoginChannel] ✅ JWT authenticated subscription: site_id=...
```

### Step 3: Production Deployment

**A. Update Production Configuration**

```bash
# SSH to production server
ssh root@167.71.206.103

# Navigate to app directory
cd /root/axiam_client_app

# Edit config/application.yml
nano config/application.yml

# Add/Update:
# AXIAM_API_BASE: "https://axiam.io"
# AXIAM_CABLE_URL: "wss://axiam.io/cable"
# REDIS_URL: "redis://localhost:6379/0"
# ACTIONCABLE_REQUIRE_JWT: "false"  # Start with false, monitor
```

**B. Deploy Code**

```bash
# Pull latest code (if using git)
git pull origin main

# Or copy updated files via scp
# scp -r /local/path/* root@167.71.206.103:/root/axiam_client_app/

# Install dependencies
docker-compose exec veritrust bundle install

# Restart application
docker-compose restart veritrust
```

**C. Verify Production Deployment**

```bash
# 1. Test JWT endpoint
curl https://veritrustai.net/auth/axiam-token

# 2. Check logs
docker logs -f axiam_client_app-veritrust_1 | grep -E "ActionCable|JWT"

# 3. Test facial login via browser
# Open: https://veritrustai.net/users/sign_in
# Complete facial login flow
```

---

## ✅ Post-Deployment Verification

### 1. Endpoint Health Check

```bash
# Development
curl http://localhost:8000/auth/axiam-token

# Production
curl https://veritrustai.net/auth/axiam-token

# Expected response:
{
  "success": true,
  "token": "eyJhbGc...",
  "expires_in": 7200,
  "expires_at": "2026-01-01T14:00:00Z"
}
```

**Status:** ⏳ Pending

### 2. ActionCable Connection Test

Open browser console and run:

```javascript
// Get JWT token
fetch('/auth/axiam-token')
  .then(r => r.json())
  .then(data => {
    console.log('JWT Token:', data.token.substring(0, 20) + '...');
    
    // Connect to ActionCable
    const cable = ActionCable.createConsumer(
      `wss://axiam.io/cable?token=${encodeURIComponent(data.token)}`
    );
    
    console.log('ActionCable consumer created');
  });
```

**Expected console output:**
```
JWT Token: eyJhbGciOiJIUzI1NiJ9...
ActionCable consumer created
```

**Status:** ⏳ Pending

### 3. Server Logs Monitoring

```bash
# Monitor for 5 minutes after deployment
docker logs -f axiam_client_app-veritrust_1 | grep -E "ActionCable|JWT|ERROR"

# Look for:
# ✅ [ActionCable] ✅ JWT authentication successful
# ✅ [FacialSignOnLoginChannel] ✅ JWT authenticated subscription
# ❌ Any ERROR messages (investigate if found)
```

**Status:** ⏳ Pending

### 4. End-to-End Testing

**Test Scenarios:**

- [ ] **Facial Login Flow**
  1. User enters email
  2. System sends push notification
  3. User scans face on mobile
  4. WebSocket receives verification
  5. User logged in successfully
  
- [ ] **Facial Signup Flow**
  1. User fills registration form
  2. QR code displayed
  3. User scans QR with mobile app
  4. Facial data captured
  5. Account created and verified

- [ ] **Token Refresh**
  1. Keep page open for 2+ hours
  2. Verify token auto-refreshes
  3. WebSocket reconnects with new token

**Status:** ⏳ Pending

### 5. Performance Check

```bash
# Check response time of JWT endpoint
time curl https://veritrustai.net/auth/axiam-token

# Expected: < 500ms

# Monitor Redis memory usage
redis-cli info memory | grep used_memory_human

# Check ActionCable connection count
docker logs axiam_client_app-veritrust_1 | grep "ActionCable.*Connected" | wc -l
```

**Status:** ⏳ Pending

---

## 🔒 Security Verification

### 1. API Secret Protection

```bash
# Verify API_SECRET is NOT exposed in:
# - Browser console
# - Network requests (DevTools)
# - HTML source code
# - JavaScript files

# Check browser console for exposed secrets:
# Open DevTools > Console
# Search for: "SECRET" or "c2328bdb"
# Expected: No results
```

**Status:** ⏳ Pending

### 2. JWT Token Storage

```javascript
// Open browser console and check:
localStorage.getItem('axiam_token')  // Should be: null
sessionStorage.getItem('axiam_token')  // Should be: null

// JWT should only be in memory (cachedJWTToken variable)
// Not accessible from global scope
```

**Status:** ⏳ Pending

### 3. HTTPS Enforcement

```bash
# Production should redirect HTTP to HTTPS
curl -I http://veritrustai.net
# Expected: 301 Moved Permanently
# Location: https://veritrustai.net
```

**Status:** ⏳ Pending

### 4. Token Revocation Test

```ruby
# Rails console test
rails console

# Get a JWT token
token_data = AxiamApi.get_jwt_token
token = token_data[:token]

# Revoke it
JwtRevocationService.revoke_token(token, reason: 'test')

# Check if revoked
JwtRevocationService.revoked?(token)
# Expected: true

# Try to connect with revoked token (should fail)
```

**Status:** ⏳ Pending

---

## 🐛 Troubleshooting Guide

### Issue 1: "Failed to get JWT token"

**Symptoms:**
- Browser console shows: "Failed to get JWT token"
- HTTP 401 or 503 error

**Debug Steps:**

```bash
# 1. Check Axiam API credentials
rails console
puts ENV['AXIAM_API_KEY']
puts ENV['AXIAM_SECRET_KEY']

# 2. Test Axiam API directly
curl -X POST http://localhost:3000/api/v1/facial_sign_on/application_auth \
  -H "Content-Type: application/json" \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "X-API-Secret: YOUR_SECRET_KEY"

# 3. Check Rails logs
tail -f log/development.log | grep AxiamApi
```

**Solutions:**
- Verify API credentials in config/application.yml
- Check Axiam server is accessible
- Verify AXIAM_API_BASE URL is correct

---

### Issue 2: "Unauthorized connection"

**Symptoms:**
- ActionCable connection rejected
- Console shows: "Unauthorized connection"

**Debug Steps:**

```bash
# 1. Check JWT secret matches
rails console
puts ENV['AXIAM_SECRET_KEY']

# 2. Verify token format
token = AxiamApi.get_jwt_token[:token]
payload = JWT.decode(token, ENV['AXIAM_SECRET_KEY'], true, algorithm: 'HS256')
puts payload

# 3. Check ActionCable logs
docker logs axiam_client_app-veritrust_1 | grep "JWT authentication failed"
```

**Solutions:**
- Ensure AXIAM_SECRET_KEY matches between VeriTrust and Axiam
- Check token hasn't expired (< 2 hours)
- Verify JWT gem is installed: `bundle list | grep jwt`

---

### Issue 3: Token Revocation Not Working

**Symptoms:**
- Revoked tokens still accepted
- JwtRevocationService.revoked? returns false

**Debug Steps:**

```bash
# 1. Check Redis connection
redis-cli ping
# Expected: PONG

# 2. Check Redis keys
redis-cli KEYS "jwt_revocation:*"

# 3. Test revocation manually
rails console
token = AxiamApi.get_jwt_token[:token]
JwtRevocationService.revoke_token(token)
# Check Redis
redis-cli GET jwt_revocation:token:HASH
```

**Solutions:**
- Verify REDIS_URL is correct in config
- Ensure Redis server is running
- Check Redis has sufficient memory

---

### Issue 4: Legacy channel_prefix Still Used

**Symptoms:**
- Logs show: "Using deprecated channel_prefix authentication"
- JWT token not being sent

**Debug Steps:**

```javascript
// Browser console
// Check WebSocket URL
console.log(App.cable.url);
// Should show: wss://axiam.io/cable?token=eyJ...
// NOT: wss://axiam.io/cable?channel_prefix=ch_...
```

**Solutions:**
- Clear browser cache and hard refresh (Ctrl+F5)
- Verify views are updated with JWT code
- Check /auth/axiam-token endpoint returns token

---

## 📊 Monitoring & Alerts

### Metrics to Track

1. **JWT Token Generation Success Rate**
   ```bash
   # Count successful JWT generations
   grep "get JWT token" log/production.log | grep -c "success: true"
   ```

2. **ActionCable JWT Authentication Rate**
   ```bash
   # Count JWT authenticated connections
   grep "ActionCable.*JWT authentication successful" log/production.log | wc -l
   ```

3. **Token Revocation Events**
   ```bash
   # Count revoked tokens
   redis-cli KEYS "jwt_revocation:token:*" | wc -l
   ```

4. **Failed Authentication Attempts**
   ```bash
   # Count failures
   grep "JWT authentication failed" log/production.log | wc -l
   ```

### Set Up Alerts

**For Production Monitoring:**

```yaml
# Example: AlertManager configuration
alerts:
  - name: high_jwt_failure_rate
    condition: jwt_failures > 10 per minute
    action: notify_team
    
  - name: redis_connection_failure
    condition: redis_errors > 5 per minute
    action: page_oncall
    
  - name: token_revocation_spike
    condition: revocations > 50 per hour
    action: security_review
```

---

## ✅ Sign-Off Checklist

Before considering deployment complete, verify:

- [ ] Bundle install completed successfully
- [ ] JWT gem installed and loaded
- [ ] /auth/axiam-token endpoint returns valid tokens
- [ ] Facial login works with JWT authentication
- [ ] Facial signup works with JWT authentication
- [ ] ActionCable logs show JWT authentication
- [ ] No errors in production logs
- [ ] Redis connection working
- [ ] Token revocation tested
- [ ] Security verification passed
- [ ] Performance metrics acceptable
- [ ] Documentation updated
- [ ] Team notified of changes

**Deployment Date:** _____________

**Deployed By:** _____________

**Verified By:** _____________

**Notes:**
_____________________________________________
_____________________________________________
_____________________________________________

---

## 📞 Rollback Plan

If issues occur after deployment:

### Immediate Rollback (Legacy Mode)

```ruby
# config/application.yml
# Keep JWT code but don't enforce it
ACTIONCABLE_REQUIRE_JWT: "false"  # Allow legacy channel_prefix

# Views will attempt JWT first, fallback to channel_prefix if fails
```

### Full Rollback (Revert to Previous Version)

```bash
# 1. Checkout previous version
git checkout <previous-commit-hash>

# 2. Reinstall dependencies
bundle install

# 3. Restart application
docker-compose restart veritrust

# 4. Verify rollback
curl https://veritrustai.net/users/sign_in
```

### Contact Information

**For Urgent Issues:**
- Internal Team: [Your team contact]
- Axiam Support: support@axiam.io (24/7)
- Axiam Security: security@axiam.io (emergencies)

---

**Document Version:** 1.0  
**Last Updated:** January 1, 2026  
**Next Review:** After successful deployment
