# Axiam Facial Sign-In Implementation Summary

**Last Updated:** November 25, 2025  
**Status:** ✅ Implementation Complete  
**Integration Type:** Direct API (No Widget)

---

## 📋 Implementation Overview

Đã implement đầy đủ Axiam Facial Sign-On theo documentation mới nhất (November 25, 2025), sử dụng **Direct API Integration** thay vì embedded widget.

---

## 🎯 What Was Implemented

### 1. Backend Services

#### **AxiamApi Service** (`app/services/axiam_api.rb`)
- ✅ `authenticated_token` - Cache JWT token (expires 30 days)
- ✅ `lookup_client(email:)` - Tìm kiếm user theo email
- ✅ `push_notification(client_id:)` - Gửi notification đến mobile app
- ✅ Auto token refresh khi expired (401/403 errors)
- ✅ Error handling với retry logic

### 2. API Controllers

#### **Api::FacialSignOnController** (`app/controllers/api/facial_sign_on_controller.rb`)
- ✅ `POST /api/facial_sign_on/lookup` - Lookup client by email
- ✅ `POST /api/facial_sign_on/push_notification` - Send push notification
- ✅ Error code mapping (1002, 1007, 1012, 1013, 1020, 1021)
- ✅ User-friendly error messages

#### **Api::SessionsController** (`app/controllers/api/sessions_controller.rb`)
- ✅ `POST /api/sessions` - Create session after facial login
- ✅ `GET /api/sessions/current` - Check current session
- ✅ `DELETE /api/sessions` - Logout
- ✅ Verify `client_id` matches `user.axiam_uid`
- ✅ Auto-update `axiam_uid` if blank

### 3. ActionCable Real-time Integration

#### **FacialSignOnLoginChannel** (`app/channels/facial_sign_on_login_channel.rb`)
- ✅ Subscribe to channel: `facial_sign_on_login_{verification_token}`
- ✅ Receive broadcasts from Axiam server when mobile app verifies login
- ✅ Logging for debugging

### 4. Frontend (Login Page)

#### **devise/sessions/new.html.erb**
- ✅ Email input with validation
- ✅ "Sign In With Face" button với Axiam logo
- ✅ ActionCable WebSocket integration
- ✅ Real-time status updates
- ✅ Error handling với specific error codes
- ✅ Loading states: "Looking up account..." → "Sending notification..." → "Waiting for face scan..." → "Login successful!"
- ✅ 5-minute timeout
- ✅ Cleanup on success/failure

---

## 🔄 Complete Login Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        FACIAL SIGN-ON LOGIN FLOW                         │
└─────────────────────────────────────────────────────────────────────────┘

1. User enters email on login page
   └─> Email validation (must contain @)

2. Click "Sign In With Face" button
   └─> Button disabled, text: "Looking up account..."

3. POST /api/facial_sign_on/lookup
   ├─> Request: { email: "user@example.com" }
   ├─> AxiamApi.authenticated_token (cached JWT)
   ├─> Call Axiam API: POST /api/v1/facial_sign_on/login/lookup_client
   └─> Response: { success: true, data: { client_id: "...", facial_sign_on_enabled: true } }
   
   Error Handling:
   ├─> Code 1007: "No account found with this email address."
   ├─> Code 1002: "Please register your face first."
   └─> Code 1013: "Account temporarily locked."

4. POST /api/facial_sign_on/push_notification
   ├─> Request: { client_id: "..." }
   ├─> Call Axiam API: POST /api/v1/facial_sign_on/login/push_notification
   ├─> Axiam sends Firebase Push Notification to mobile app
   └─> Response: { success: true, data: { verification_token: "...", site_id: "..." } }
   
   Error Handling:
   ├─> Code 1012: "Please register your mobile device first."
   └─> Code 1020/1021: "Too many requests. Please try again later."

5. Subscribe to ActionCable WebSocket
   ├─> URL: wss://api.axiam.io/cable
   ├─> Channel: FacialSignOnLoginChannel
   ├─> Params: { token: verification_token }
   ├─> Stream: facial_sign_on_login_{verification_token}
   └─> Status: "Notification sent! Please check your mobile app."

6. User opens mobile app, receives notification
   └─> Mobile app shows facial scan prompt

7. User scans face on mobile app
   ├─> Mobile app: POST /api/v1/facial_sign_on/login/compare_face
   ├─> Axiam compares scanned face with registered face
   └─> Mobile app: POST /api/v1/facial_sign_on/login/verify_token

8. Axiam server broadcasts to ActionCable
   ├─> Channel: facial_sign_on_login_{verification_token}
   └─> Message: { status: "verified", client_id: "...", email: "..." }

9. Web client receives ActionCable broadcast
   └─> Status: "Login verified! Redirecting..."

10. POST /api/sessions (Create session)
    ├─> Request: { client_id: "...", email: "...", login_method: "facial_sign_on" }
    ├─> Find user by email
    ├─> Verify client_id matches user.axiam_uid
    ├─> Update user.axiam_uid if blank
    ├─> sign_in(user) using Devise
    └─> Response: { success: true, user: { id: ..., email: "..." } }

11. Redirect to dashboard
    └─> window.location.href = '/'

12. Cleanup
    ├─> Unsubscribe from ActionCable
    ├─> Disconnect WebSocket
    └─> Clear timeout
```

---

## 🗄️ Database Schema

### Users Table
```ruby
t.string "email", null: false, index: true
t.string "axiam_uid"  # Axiam client_id (UUID)
t.datetime "created_at"
t.datetime "updated_at"
```

**Important:** `axiam_uid` chính là `client_id` từ Axiam API.

---

## 🔑 Environment Variables

### Development Environment (Docker localhost:3030)

Development sử dụng Axiam development server chạy trên Docker (`localhost:3000`):

```bash
# config/application.yml or .env

# Axiam API Configuration (Development)
AXIAM_API_BASE=http://localhost:3000
AXIAM_API_KEY=your_dev_api_key_here
AXIAM_SECRET_KEY=your_dev_secret_key_here
AXIAM_DOMAIN=localhost

# ActionCable WebSocket URL (Development)
AXIAM_CABLE_URL=ws://localhost:3000/cable

# Rails environment
RAILS_ENV=development
```

**Docker Setup:**
- VeriTrust App: `http://localhost:3030` (trustid-web-1 container)
- Axiam API: `http://localhost:3000` (axiamai_rails-app-1 container)
- MySQL (VeriTrust): `localhost:3308`
- MySQL (Axiam): `localhost:3307`
- Redis: `localhost:6379`

### Production Environment (veritrustai.net)

Production sử dụng Axiam production server:

```bash
# config/application.yml or .env

# Axiam API Configuration (Production)
AXIAM_API_BASE=https://axiam.io/api
AXIAM_API_KEY=your_production_api_key_here
AXIAM_SECRET_KEY=your_production_secret_key_here
AXIAM_DOMAIN=veritrustai.net

# ActionCable WebSocket URL (Production)
AXIAM_CABLE_URL=wss://axiam.io/cable

# Rails environment
RAILS_ENV=production
```

**Security Notes:**
- ✅ `AXIAM_SECRET_KEY` never exposed to frontend
- ✅ `authenticated_token` cached server-side only
- ✅ All API calls use `Authorization: Bearer {token}`
- ✅ Use HTTPS/WSS in production (HTTP/WS in development only)
- ✅ Different API keys for development and production
- ✅ Domain must match registered site in Axiam database

---

## 📡 API Endpoints

### Backend Endpoints (Your Rails App)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/facial_sign_on/lookup` | Lookup client by email |
| POST | `/api/facial_sign_on/push_notification` | Send push notification |
| POST | `/api/sessions` | Create session after facial login |
| GET | `/api/sessions/current` | Check current session |
| DELETE | `/api/sessions` | Logout |

### Axiam API Endpoints (External)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/facial_sign_on/application_auth` | Get authenticated token |
| POST | `/api/v1/facial_sign_on/login/lookup_client` | Lookup client by email |
| POST | `/api/v1/facial_sign_on/login/push_notification` | Send push notification |
| POST | `/api/v1/facial_sign_on/login/verify_token` | Verify login (called by mobile app) |

---

## 🧪 Testing Guide

### 1. Setup Environment Variables

**Development:**
```bash
# Copy example file
cp .env.example .env

# Edit .env with development settings
AXIAM_API_BASE=http://localhost:3000
AXIAM_API_KEY=your_dev_api_key
AXIAM_SECRET_KEY=your_dev_secret_key
AXIAM_DOMAIN=localhost
AXIAM_CABLE_URL=ws://localhost:3000/cable
```

**Production:**
```bash
# Edit config/application.yml with production settings
AXIAM_API_BASE=https://axiam.io/api
AXIAM_API_KEY=your_production_api_key
AXIAM_SECRET_KEY=your_production_secret_key
AXIAM_DOMAIN=veritrustai.net
AXIAM_CABLE_URL=wss://axiam.io/cable
```

### 2. Test Application Authentication
```bash
# Rails console
rails c

# Test authentication
token = AxiamApi.authenticated_token
puts token
# Should return: "eyJhbGciOiJIUzI1NiJ9..."

# Force refresh
token = AxiamApi.authenticated_token(force_refresh: true)
```

### 3. Test Client Lookup
```bash
# Rails console
result = AxiamApi.lookup_client(email: 'user@example.com')
puts result.inspect

# Expected success:
# {
#   "success" => true,
#   "data" => {
#     "client_id" => "38b69dca-02f4-44f5-883a-cb7fd730eb07",
#     "email" => "user@example.com",
#     "facial_sign_on_enabled" => true
#   }
# }
```

### 4. Test Push Notification
```bash
# Rails console
result = AxiamApi.push_notification(client_id: 'your-client-id-here')
puts result.inspect

# Expected success:
# {
#   "success" => true,
#   "data" => {
#     "verification_token" => "a1b2c3d4e5f6...",
#     "site_id" => "site-uuid-123"
#   }
# }
```

### 5. Test Login Flow (Browser)
1. Navigate to `/users/sign_in`
2. Enter email address
3. Click "Sign In With Face"
4. Check browser console for logs
5. Open mobile app (should receive notification)
6. Complete face scan on mobile
7. Web page should redirect to dashboard

### 6. Test Error Scenarios

**Email not found:**
```
Input: nonexistent@example.com
Expected: "No account found with this email address."
```

**Facial not enabled:**
```
Input: user-without-facial@example.com
Expected: "Please register your face first."
```

**Account locked:**
```
Input: locked-user@example.com
Expected: "Account temporarily locked."
```

**Mobile device not registered:**
```
Expected: "Please register your mobile device first."
```

**Timeout:**
```
Wait 5 minutes without completing face scan
Expected: "Login timeout. Please try again."
```

---

## 🐛 Debugging

### Check Logs

```bash
# Rails logs
tail -f log/development.log | grep -i "axiam\|facial"

# Look for:
# [AxiamApi] Authenticated successfully. Token expires in 2592000s
# [AxiamApi] Client found: user@example.com
# [AxiamApi] Push notification sent. Token: a1b2c3d4e5f6...
# [FacialSignOnLoginChannel] Subscribed to: facial_sign_on_login_a1b2c3d4e5f6...
# [SessionsController] User logged in via facial sign-on: user@example.com
```

### Check ActionCable Connection

```javascript
// Browser console
console.log(cable)
console.log(subscription)

// Check if connected
cable.connection.isActive()  // Should return true
```

### Common Issues

**Issue 1: "Authentication failed"**
- Check `AXIAM_API_KEY` and `AXIAM_SECRET_KEY` in `.env`
- Verify domain matches registered domain

**Issue 2: "Token expired"**
- Cache auto-refreshes on 401/403 errors
- Force refresh: `AxiamApi.authenticated_token(force_refresh: true)`

**Issue 3: "ActionCable not connecting"**
- Check `AXIAM_CABLE_URL` in `.env`
- Verify HTTPS/WSS (not HTTP/WS)
- Check CORS settings on Axiam server

**Issue 4: "Client ID mismatch"**
- User's `axiam_uid` doesn't match Axiam's `client_id`
- Reset user: `user.update(axiam_uid: nil)`

---

## 🔒 Security Checklist

- ✅ `AXIAM_SECRET_KEY` stored in environment variables
- ✅ `authenticated_token` cached server-side only
- ✅ CSRF protection on API endpoints
- ✅ Client ID verification before session creation
- ✅ HTTPS required for production
- ✅ WSS (secure WebSocket) for ActionCable
- ✅ Rate limiting handled by Axiam API
- ✅ Error messages don't expose sensitive info
- ✅ Session timeout (Devise default: 30 minutes)

---

## 📝 Code Files Changed

### Created:
- `app/controllers/api/facial_sign_on_controller.rb`
- `app/controllers/api/sessions_controller.rb`
- `app/channels/facial_sign_on_login_channel.rb`

### Modified:
- `app/services/axiam_api.rb` - Complete rewrite for new API
- `app/views/devise/sessions/new.html.erb` - Direct API integration
- `config/routes.rb` - Added API routes
- `app/controllers/api/sessions_controller.rb` - Use `axiam_uid` instead of `axiam_client_id`

### Database:
- Users table already has `axiam_uid` column (no migration needed)

---

## 🚀 Next Steps

### For Development:
1. Get Axiam staging credentials from Axiam support
2. Update `.env` with staging credentials
3. Test full login flow with test account
4. Test error scenarios

### For Production:
1. Get production credentials from Axiam
2. Update production `.env` variables
3. Verify domain whitelist with Axiam
4. Enable HTTPS (required)
5. Test with real mobile app users
6. Monitor logs for errors
7. Set up error tracking (Sentry, Rollbar, etc.)

### Optional Enhancements:
- [ ] Add remember me functionality
- [ ] Add login activity tracking
- [ ] Add email notifications on new login
- [ ] Add 2FA as fallback option
- [ ] Add admin dashboard for facial sign-on stats
- [ ] Add rate limiting on frontend

---

## 📞 Support

**Axiam Support:**
- Email: support@axiam.io
- Technical: developers@axiam.io
- Documentation: https://api.axiam.io/public/facial_sign_on_api_doc.html

**Implementation Questions:**
- Check logs first: `tail -f log/development.log`
- Test in Rails console before browser
- Verify environment variables are set

---

## ✅ Implementation Checklist

- [x] AxiamApi service với authenticated_token caching
- [x] lookup_client API endpoint
- [x] push_notification API endpoint
- [x] ActionCable channel subscription
- [x] Session creation with client_id verification
- [x] Frontend với ActionCable integration
- [x] Error handling for all error codes
- [x] Loading states và user feedback
- [x] Cleanup on success/failure/timeout
- [x] Database schema ready (axiam_uid exists)
- [x] Routes configured
- [x] CSRF protection
- [x] Logging for debugging

**Status: ✅ READY FOR TESTING**

---

**Last Updated:** November 25, 2025  
**Version:** 1.0  
**Integration Type:** Direct API (No Widget)
