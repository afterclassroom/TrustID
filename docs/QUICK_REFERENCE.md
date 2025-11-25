# VeriTrust Quick Reference Card

**For Developers** | Last Updated: November 25, 2025

---

## 🚀 Quick Start

```bash
# Setup
cp .env.example .env && nano .env

# Check environment
ruby script/check_environment.rb

# Start (Docker)
docker-compose up -d

# Console
docker exec -it trustid-web-1 rails console

# Test Axiam
AxiamApi.authenticated_token
```

---

## 🌍 Environments

### Development
- **App:** http://localhost:3030
- **Axiam:** http://localhost:3000
- **Protocol:** HTTP/WS

### Production
- **App:** https://veritrustai.net
- **Axiam:** https://axiam.io/api
- **Protocol:** HTTPS/WSS

---

## 🔑 Environment Variables

```bash
# Development (.env)
AXIAM_API_BASE=http://localhost:3000
AXIAM_DOMAIN=localhost
AXIAM_CABLE_URL=ws://localhost:3000/cable

# Production (config/application.yml)
AXIAM_API_BASE=https://axiam.io/api
AXIAM_DOMAIN=veritrustai.net
AXIAM_CABLE_URL=wss://axiam.io/cable
```

---

## 🛠️ Common Commands

```bash
# Docker
docker-compose up -d              # Start all
docker-compose logs -f            # View logs
docker exec -it trustid-web-1 sh  # Shell

# Rails
rails console                     # Console
rails routes | grep facial        # Routes
rails db:migrate                  # Migrate

# Assets
rails assets:precompile           # Compile
rails tailwindcss:build           # Build CSS

# Testing
curl localhost:3030/up            # Health check
```

---

## 📡 API Endpoints

### Backend (Rails)
```
POST   /api/facial_sign_on/lookup
POST   /api/facial_sign_on/push_notification
POST   /api/sessions
GET    /api/sessions/current
DELETE /api/sessions
```

### Axiam (External)
```
POST   /api/v1/facial_sign_on/application_auth
POST   /api/v1/facial_sign_on/login/lookup_client
POST   /api/v1/facial_sign_on/login/push_notification
```

---

## 🧪 Testing Code

```ruby
# Rails console

# 1. Test auth
token = AxiamApi.authenticated_token
puts token

# 2. Test lookup
result = AxiamApi.lookup_client(email: 'user@example.com')
puts result.inspect

# 3. Test push
result = AxiamApi.push_notification(client_id: 'client-uuid')
puts result.inspect

# 4. Check user
user = User.find_by(email: 'user@example.com')
puts user.axiam_uid
```

---

## 🐛 Debugging

```bash
# Logs
tail -f log/development.log | grep -i axiam

# Check vars
rails runner "puts ENV['AXIAM_API_BASE']"

# Clear cache
rails runner "Rails.cache.clear"

# Check containers
docker ps | grep -E "trustid|axiam"
```

---

## ❌ Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Authentication failed` | Invalid credentials | Check AXIAM_API_KEY |
| `Client not found` | User not in Axiam | Complete facial signup |
| `Connection refused` | Axiam not running | Start Docker container |
| `ActionCable not connecting` | Wrong URL | Check AXIAM_CABLE_URL |
| `Domain mismatch` | Wrong domain config | Verify AXIAM_DOMAIN |

---

## 📚 Documentation

| File | Purpose |
|------|---------|
| README.md | Overview |
| SETUP_GUIDE.md | Full setup guide |
| AXIAM_FACIAL_SIGNIN_IMPLEMENTATION.md | Technical details |
| PRODUCTION_DEPLOYMENT_CHECKLIST.md | Deployment guide |
| ENVIRONMENT_SETUP_SUMMARY.md | Complete summary |

---

## 🔗 Important URLs

### Development
- App: http://localhost:3030
- Login: http://localhost:3030/users/sign_in
- Signup: http://localhost:3030/facial_signup/new
- Axiam: http://localhost:3000

### Production
- App: https://veritrustai.net
- Login: https://veritrustai.net/users/sign_in
- Signup: https://veritrustai.net/facial_signup/new

---

## 📞 Support

**Axiam:** support@axiam.io  
**Docs:** SETUP_GUIDE.md  
**Logs:** `tail -f log/development.log`

---

## ✅ Quick Checks

```bash
# All checks in one script
ruby script/check_environment.rb

# Manual checks
echo $AXIAM_API_BASE        # Should be set
docker ps | grep axiam      # Should be running
curl localhost:3000/up      # Should return OK
rails console               # Should start
```

---

**Keep this card handy!** 📋
