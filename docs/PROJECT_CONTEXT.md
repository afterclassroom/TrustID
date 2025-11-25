# Axiam Webclient - Development History & Context

**Project:** Rails 7.1.6 Webclient for Axiam Facial Sign-In Integration  
**Timeline:** October - November 2025  
**Language:** Vietnamese (with English technical terms)

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Technical Stack](#technical-stack)
3. [Major Features Implemented](#major-features-implemented)
4. [Key Files & Their Purpose](#key-files--their-purpose)
5. [Integration Details](#integration-details)
6. [Issues Fixed](#issues-fixed)
7. [Current State](#current-state)
8. [Important Notes](#important-notes)

---

## 🎯 Project Overview

Rails webclient integrating with **Axiam Facial Sign-In Service** (axiam.io) to enable users to:
- Login using facial recognition (instead of password)
- Register/enable facial sign-in for their account
- Receive real-time notifications during facial setup process

**Environments:**
- Development: `localhost:3030` (Docker)
- Staging: `staging.axiam.io`
- Production: `webclient.axiam.io`, `teranet.axiam.io`

---

## 🛠 Technical Stack

**Backend:**
- Ruby 3.2.8
- Rails 7.1.6
- MySQL 8.1
- Devise (authentication)
- HTTParty (API calls to Axiam)

**Frontend:**
- Bootstrap 5
- SweetAlert2 (notifications)
- ActionCable (WebSocket for real-time events)
- Axiam Facial Login Widget v2.1.0

**Infrastructure:**
- Docker Compose
- AWS S3 (file storage)
- Redis (optional caching)

---

## ✨ Major Features Implemented

### 1. Facial Sign-In on Login Page
**File:** `app/views/devise/sessions/new.html.erb`

- Integrated Axiam Widget v2.0 directly into Devise login page
- Users can choose: Email/Password OR Facial Sign-In
- Widget loads from Axiam server: `https://axiam.io/widget/facial-login.js?v=2.1.0`

**Flow:**
1. User enters email → Click "Sign In with Face"
2. Widget calls Axiam API to send push notification to mobile
3. User approves on mobile app → Facial verification
4. Widget auto-submits to `/facial_sign_on/verified_login`
5. Backend validates → Login success

**Key Changes:**
- Added `new` action in `Devise::SessionsController` to fetch JWT token
- Widget config includes CSRF token for security
- Widget positioned outside `<form>` tag to prevent accidental form submission

---

### 2. Facial Sign-In Setup Page (Enable Feature)
**File:** `app/views/devise/registrations/enable_facial_sign_on.html.erb`

**Purpose:** Allow users to enable facial sign-in for their account

**Flow:**
1. User navigates to settings → Enable Facial Sign-In
2. Backend calls Axiam API: `POST /api/v1/facial_sign_on/client/qrcode`
3. QR code displayed on webclient
4. **WebSocket subscription** to `FacialSignOnDeviceChannel` (Axiam server)
5. User scans QR on mobile → Event: `{status: "registered"}`
6. User uploads facial on mobile → Event: `{status: "uploaded"}`
7. SweetAlert popup → User chooses: "Go to Dashboard" or "Logout"

**Technical Implementation:**
- Direct ActionCable connection to Axiam WebSocket server
- Auto-detect environment: `ws://localhost:3000` (dev), `wss://axiam.io` (prod)
- Real-time event handling without polling
- Step-by-step UI updates based on WebSocket events

---

### 3. Domain-Based Branding
**Files:** 
- `app/views/home/index.html.erb`
- `app/views/layouts/_header.html.erb`

**Feature:** Show different branding based on domain

```ruby
<% if request.host == 'teranet.axiam.io' %>
  <h1>Teranet Dummy Test Site</h1>
<% else %>
  <h1>Axiam Client</h1>
<% end %>
```

---

### 4. Terminology Standardization
**Changed:** "Facial Sign On" → "Facial Sign In" (7 files updated)

**Reason:** Better UX, matches industry standard ("sign in" vs "sign on")

**Files affected:**
- `app/views/home/index.html.erb`
- `app/views/devise/registrations/enable_facial_sign_on.html.erb`
- `app/views/devise/registrations/edit.html.erb`
- `app/views/facial_sign_on/subscribe.html.erb`
- `app/controllers/facial_sign_on_controller.rb`

---

## 📁 Key Files & Their Purpose

### Controllers

**`app/controllers/devise/sessions_controller.rb`**
```ruby
class Devise::SessionsController < DeviseController
  prepend_before_action only: [:create, :destroy] do
    @axiam_auth_token = get_axiam_auth_token
  end
  
  def new
    @axiam_auth_token = get_axiam_auth_token
    super
  end
  
  private
  
  def get_axiam_auth_token
    # Server-side JWT token generation
    # Cached for 30 days to reduce API calls
    Rails.cache.fetch('axiam_auth_token', expires_in: 30.days) do
      AxiamApi.get_auth_token
    end
  end
end
```

**`app/controllers/facial_sign_on_controller.rb`**
- Handles facial login flow
- `verified_login` action: Validates and logs in user after facial verification
- WebSocket token generation for subscribe page

**`app/controllers/users/registrations_controller.rb`**
- `enable_facial_sign_on` action: Generate QR code for facial setup

---

### Views

**`app/views/devise/sessions/new.html.erb`**
- Main login page
- Email/Password form + Axiam Widget
- Widget loads conditionally if `@axiam_auth_token` present

**`app/views/devise/registrations/enable_facial_sign_on.html.erb`**
- QR code display
- WebSocket connection to Axiam
- Real-time setup progress tracking
- SweetAlert2 notifications

**`app/views/facial_sign_on/subscribe.html.erb`**
- Legacy facial login page (separate from Devise)
- Uses AxiamActionCableClient
- Waits for facial verification

---

### Channels

**`app/channels/facial_sign_on_device_channel.rb`**
```ruby
class FacialSignOnDeviceChannel < ApplicationCable::Channel
  def subscribed
    client_id = params[:client_id]
    
    unless client_id.present?
      Rails.logger.warn "[FacialSignOnDeviceChannel] Reject: missing client_id"
      reject
      return
    end
    
    channel_name = "facial_sign_on_device_#{client_id}"
    stream_from channel_name
    
    Rails.logger.info "[FacialSignOnDeviceChannel] Subscribed to #{channel_name}"
  end
end
```

**Purpose:** Receive WebSocket events from Axiam when user completes facial setup on mobile

---

### JavaScript Assets

**`app/assets/javascripts/axiam-actioncable-client.js`**
- Helper class for connecting to Axiam WebSocket
- Handles multi-tenant channel prefixes
- Used in legacy facial login flow

**`app/assets/javascripts/facial_sign_on_secure_token.js`**
- Secure token fetching via CSRF-protected API
- Prevents token exposure in HTML

---

## 🔗 Integration Details

### Axiam API Endpoints Used

**1. Get Auth Token (JWT)**
```
POST https://axiam.io/api/v1/auth/jwt
Headers:
  Authorization: Bearer {SECRET_KEY}
  X-API-Key: {API_KEY}

Response:
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expires_at": "2025-12-10T00:00:00Z"
}
```

**2. Generate QR Code**
```
POST https://axiam.io/api/v1/facial_sign_on/client/qrcode
Headers:
  Authorization: Bearer {JWT_TOKEN}
Body:
{
  "id": "client_axiam_uid"
}

Response:
{
  "success": true,
  "data": {
    "qrcode_base64": "iVBORw0KGgoAAAANSUhEUg..."
  }
}
```

**3. Verified Login**
- Called by Axiam Widget after facial verification
- Backend receives `client_id` and validates with Axiam

---

### WebSocket Integration

**Connection:**
```javascript
// Development
App.cable = ActionCable.createConsumer('ws://localhost:3000/cable');

// Production
App.cable = ActionCable.createConsumer('wss://axiam.io/cable');
```

**Subscription:**
```javascript
App.cable.subscriptions.create(
  {
    channel: "FacialSignOnDeviceChannel",
    client_id: "user_axiam_uid"
  },
  {
    connected() {
      console.log('WebSocket connected');
    },
    
    received(data) {
      // data.status: "registered" or "uploaded"
      handleSetupEvent(data);
    }
  }
);
```

**Events from Axiam:**
```json
// Event 1: Device Registered
{
  "status": "registered",
  "client_id": "xxx",
  "message": "Device registered successfully"
}

// Event 2: Facial Uploaded
{
  "status": "uploaded",
  "client_id": "xxx",
  "facial_url": "https://s3.amazonaws.com/...",
  "message": "Facial image uploaded successfully"
}
```

---

## 🐛 Issues Fixed

### 1. Devise SessionsController Syntax Error
**Error:** `syntax error, unexpected '{', expecting 'end'`

**Cause:** Using brace block after keyword arguments
```ruby
# ❌ Wrong
prepend_before_action only: [:create] { ... }

# ✅ Fixed
prepend_before_action only: [:create] do
  ...
end
```

---

### 2. File Duplication in new.html.erb
**Problem:** Content duplicated 2-3 times when using `create_file` tool

**Solution:** Used PowerShell to overwrite file completely
```powershell
[System.IO.File]::WriteAllText('path', 'content', [System.Text.Encoding]::UTF8)
```

---

### 3. Widget 422 Unprocessable Content
**Error:** POST `/users/sign_in` returns 422 when clicking widget button

**Cause:** Missing CSRF token in widget submission

**Fix:** Added CSRF token to widget init
```javascript
AxiamFacialLogin.init({
  // ...
  csrfToken: document.querySelector('meta[name="csrf-token"]')?.content
});
```

---

### 4. Widget Submitting Wrong Form
**Problem:** Widget button triggered Devise login form instead of facial login

**Cause:** Widget container was **inside** `<form>` tag

**Fix:** Moved widget container outside form
```html
<form>...</form>  <!-- Email/Password form -->
<div class="text-center my-3"><span>or</span></div>
<div id="axiam-facial-login"></div>  <!-- Widget OUTSIDE form -->
```

---

### 5. Logout Error: undefined method
**Error:** `undefined method 'verify_signed_out_user'`

**Cause:** Custom before_action referencing non-existent method

**Fix:** Removed problematic line
```ruby
# ❌ Removed this line
prepend_before_action :verify_signed_out_user, only: :destroy
```

---

### 6. ActionCable Initialization Error
**Error:** "Cannot read properties of undefined (reading 'subscriptions')"

**Timeline:**
1. **First attempt:** Used `initAxiamClientIfNeeded()` → Failed
2. **Second attempt:** Wait/retry logic for `App.cable` → Timeout after 10 attempts
3. **Final solution:** Direct `ActionCable.createConsumer()` with environment detection

**Working Code:**
```javascript
if (!App.cable) {
  let url = (localhost) ? 'ws://localhost:3000/cable' : 'wss://axiam.io/cable';
  App.cable = ActionCable.createConsumer(url);
}

App.cable.subscriptions.create({ channel: "FacialSignOnDeviceChannel", ... });
```

---

### 7. Logout Button Route Error
**Error:** `No route matches [GET] "/users/sign_out"`

**Cause:** Devise logout requires DELETE method, not GET

**Fix:** Create form dynamically with proper method
```javascript
const form = document.createElement('form');
form.method = 'POST';
form.action = '/users/sign_out';

// Add _method=delete
const methodInput = document.createElement('input');
methodInput.type = 'hidden';
methodInput.name = '_method';
methodInput.value = 'delete';
form.appendChild(methodInput);

// Add CSRF token
const csrfInput = document.createElement('input');
csrfInput.type = 'hidden';
csrfInput.name = 'authenticity_token';
csrfInput.value = csrfToken;
form.appendChild(csrfInput);

form.submit();
```

---

### 8. Widget Version Caching
**Problem:** Browser cached old `facial-login.js` despite updating to v2.1.0

**Solution:** Added timestamp to force cache bust
```erb
<script src="<%= axiam_base %>/widget/facial-login.js?v=2.1.0&t=<%= Time.now.to_i %>"></script>
```

---

## 📊 Current State

### Completed Features ✅

1. **Login Page Integration**
   - Axiam Widget v2.1.0 integrated into Devise login
   - Email/Password OR Facial Sign-In options
   - CSRF protection
   - Clean UI with "or" divider

2. **Facial Setup Flow**
   - QR code generation via Axiam API
   - Real-time WebSocket events (device registration, facial upload)
   - SweetAlert2 notifications
   - Action buttons (Dashboard/Logout) after setup complete

3. **Domain-Based Branding**
   - `teranet.axiam.io` shows custom branding
   - Other domains show default Axiam branding

4. **Terminology Consistency**
   - All "Facial Sign On" changed to "Facial Sign In"
   - Applied across 7 files

5. **Error Handling**
   - Multiple syntax errors fixed
   - Form submission conflicts resolved
   - WebSocket initialization issues fixed
   - Logout flow corrected

6. **Security**
   - JWT token fetched server-side (never exposed to browser)
   - CSRF tokens on all forms
   - Widget submissions validated backend

---

### Pending/Future Improvements 🔄

1. **Widget Error Messages**
   - Current: Generic "Something went wrong"
   - Requested: Show API `user_message` field
   - **Action:** Created `AXIAM_WIDGET_ERROR_HANDLING_REQUEST.md` for Axiam team

2. **Widget Callbacks**
   - Requested `onError` and `onSuccess` callbacks for custom handling
   - Waiting for Axiam to implement

3. **Performance**
   - Consider moving to Dev Container for faster Copilot
   - (Note: Conversation history doesn't sync to container)

---

## 📝 Important Notes

### Environment Variables

```bash
# Required
AXIAM_API_KEY=your_public_api_key
AXIAM_SECRET_KEY=your_secret_key

# Optional
AXIAM_WIDGET_URL=http://localhost:3000  # For local Axiam development
REDIS_URL=redis://localhost:6379/0      # For caching
```

---

### Routes

```ruby
# Devise routes
devise_for :users, controllers: {
  sessions: 'devise/sessions',
  registrations: 'users/registrations'
}

# Facial sign-on routes
namespace :facial_sign_on do
  get 'login', to: 'facial_sign_on#login'
  post 'verified_login', to: 'facial_sign_on#verified_login'
  get 'subscribe', to: 'facial_sign_on#subscribe'
end

# User settings
get 'enable_facial_sign_on', to: 'users/registrations#enable_facial_sign_on'
```

---

### Docker Commands

```bash
# Start services
docker compose up -d

# Restart Rails server
docker compose restart web

# View logs
docker compose logs -f web

# Enter Rails console
docker compose exec web rails console

# Run migrations
docker compose exec web rails db:migrate

# Check container status
docker compose ps
```

---

### Database

**User Model:**
- `email` - Primary authentication
- `axiam_uid` - Client ID in Axiam system
- `encrypted_password` - Devise password (optional if using facial only)

**Key Columns for Facial Login:**
- `axiam_uid` must be set to enable facial sign-in
- Created when user enables facial feature

---

### Deployment Checklist

Before deploying to staging/production:

1. ✅ Update `facial-login.js` version with cache-bust timestamp
2. ✅ Set correct `AXIAM_API_KEY` and `AXIAM_SECRET_KEY` env vars
3. ✅ Verify WebSocket URL points to correct Axiam server
4. ✅ Test login flow: Email → Widget → Facial verification → Login
5. ✅ Test setup flow: QR scan → Device registration → Facial upload
6. ✅ Check CORS settings if WebSocket fails
7. ✅ Verify ActionCable routes are accessible
8. ✅ Test logout button (DELETE method)
9. ✅ Clear browser cache and test widget loading

---

## 🔗 External Resources

**Axiam Documentation:**
- API Docs: `https://axiam.io/facial-sign-on/document`
- Widget Integration Guide: (Provided by Axiam team)
- WebSocket Setup Guide: `AXIAM_WIDGET_ERROR_HANDLING_REQUEST.md`

**Rails/Devise:**
- Devise: `https://github.com/heartcombo/devise`
- ActionCable: `https://guides.rubyonrails.org/action_cable_overview.html`

**Frontend:**
- SweetAlert2: `https://sweetalert2.github.io/`
- Bootstrap 5: `https://getbootstrap.com/`

---

## 🎓 Lessons Learned

1. **Widget Integration:**
   - Always place widget container **outside** form tags
   - Include CSRF token in widget config
   - Use server-side JWT token generation (never expose secret key)

2. **WebSocket:**
   - Subscribe **before** displaying QR code to avoid missing events
   - Use environment detection for WebSocket URLs
   - Direct `ActionCable.createConsumer()` is simpler than helper libraries

3. **Devise Customization:**
   - Override controllers with `controllers: { sessions: 'devise/sessions' }`
   - Use `do...end` blocks for before_action with params
   - Don't rely on undocumented Devise methods

4. **Dev Container:**
   - Conversation history doesn't sync between local and container
   - Use `Reopen in Container` (not `Attach`) to maintain context
   - Remove unnecessary `postCreateCommand` if docker-compose handles it

5. **Error Handling:**
   - Generic error messages frustrate users
   - Request API to return `user_message` field
   - Provide actionable error messages (what to do next)

---

## 📞 Support Contacts

**Axiam Team:**
- Support: `support@axiam.io`
- API Issues: (Contact via support)
- Widget Updates: (Via support ticket)

**Internal Team:**
- Backend Lead: (Your team structure)
- Frontend Lead: (Your team structure)
- DevOps: (Your team structure)

---

**Last Updated:** November 10, 2025  
**Document Version:** 1.0  
**Maintained by:** Development Team

---

## Quick Reference Commands

```bash
# Start development
docker compose up -d

# View logs
docker compose logs -f web

# Rails console
docker compose exec web rails c

# Database migrations
docker compose exec web rails db:migrate

# Restart after code changes
docker compose restart web

# Test WebSocket connection
# (Open browser console, check for ActionCable logs)

# Git workflow
git status
git add .
git commit -m "feat: description"
git push origin main
```

---

**End of Document**

This document serves as a comprehensive reference for anyone working on this project, including AI assistants in Dev Containers who need context about the project history and implementation details.
