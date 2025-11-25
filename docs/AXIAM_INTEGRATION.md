# Axiam Facial Authentication Integration Guide

## Overview
VeriTrust integrates with Axiam for passwordless facial authentication (Sign Up with Face & Sign In with Face).

## Implementation Status
✅ **Complete** - Both signup and signin flows working in production

## Quick Start

### 1. Environment Variables
```bash
# Required for Axiam API
AXIAM_API_KEY=your_api_key
AXIAM_DOMAIN=your_domain  # e.g., veritrustai.net

# For ActionCable (public credentials only)
AXIAM_SERVER_URL=wss://axiam.io/cable  # or staging URL
AXIAM_CHANNEL_PREFIX=your_prefix
```

### 2. Sign Up with Face Flow
1. User enters email and full name at `/users/sign_up`
2. System calls `AxiamApi.create_client()` to create Axiam client
3. Verification email sent with link
4. User clicks link → redirected to QR code page
5. User scans QR with Axiam mobile app
6. Mobile app captures facial image and uploads
7. WebSocket notifies browser → User record created with `axiam_uid` and `avatar`
8. User redirected to login page

### 3. Sign In with Face Flow
1. User enters email at `/users/sign_in`
2. System calls `AxiamApi.lookup_client()` to get `client_id`
3. Push notification sent to user's mobile via `AxiamApi.push_notification()`
4. User approves on mobile app
5. WebSocket notifies browser via `FacialSignOnLoginChannel`
6. Session created, user logged in

## Key Files

### Controllers
- `app/controllers/facial_signup/facial_signup_controller.rb` - Signup flow
- `app/controllers/api/facial_sign_on_controller.rb` - Lookup & push notification
- `app/controllers/api/sessions_controller.rb` - Session management

### Services
- `app/services/axiam_api.rb` - Axiam API wrapper

### Channels
- `app/channels/facial_sign_on_login_channel.rb` - Login WebSocket
- `app/channels/facial_sign_on_device_channel.rb` - Signup WebSocket

### Views
- `app/views/users/registrations/new.html.erb` - Sign up page
- `app/views/devise/sessions/new.html.erb` - Sign in page
- `app/views/facial_signup/facial_signup/pending.html.erb` - Email pending
- `app/views/facial_signup/facial_signup/show_qr.html.erb` - QR code page

## Security Notes

### ✅ Implemented
- Redis credentials NOT exposed to browser (server-side only)
- CSRF protection enabled
- Secure token generation for email verification
- Avatar download from S3 over HTTPS

### ⚠️ Recommendations for Axiam Team
See `docs/archive/AXIAM_SECURITY_RECOMMENDATIONS.md` for detailed security review.

## API Reference

### AxiamApi Service Methods

```ruby
# Create new client (signup)
AxiamApi.create_client(email: string, full_name: string)
# Returns: { success: bool, data: { client_id, site_id } }

# Lookup existing client (signin)
AxiamApi.lookup_client(email: string)
# Returns: { success: bool, data: { client_id } }

# Send push notification
AxiamApi.push_notification(client_id: string, action: 'login'|'signup')
# Returns: { success: bool }

# Generate QR code
AxiamApi.generate_qrcode(client_id: string, action: 'login'|'signup')
# Returns: { success: bool, data: { qrcode_base64 } }
```

## Troubleshooting

### Issue: WebSocket not connecting
**Solution:** Check `AXIAM_SERVER_URL` matches environment (staging vs production)

### Issue: Push notification fails
**Solution:** Verify user has Axiam mobile app installed and registered

### Issue: QR code not displaying
**Solution:** Check `client_id` in session and Axiam API response

### Issue: User created without avatar
**Solution:** Check S3 URL accessibility and download permissions

## Migration Notes
- Old URL `/facial_signup/new` deprecated → use `/users/sign_up`
- All auth pages use shared CSS: `app/assets/stylesheets/auth_pages.css`
- Full name now saved to `users.full_name` column

## Support
For Axiam API issues, contact Axiam support team.
For VeriTrust integration issues, check logs in `/var/www/app/log/production.log`
