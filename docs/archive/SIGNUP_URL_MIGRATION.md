# Sign Up With Face - URL Migration

## Overview
The facial sign-up functionality has been migrated from `/facial_signup/new` to `/users/sign_up` to follow Rails conventions and integrate seamlessly with Devise authentication.

## Changes Made

### 1. Routes Configuration (`config/routes.rb`)
**Changed:**
- Removed `GET /facial_signup/new` route
- Kept API endpoints for facial signup workflow:
  - `POST /facial_signup/create` - Create Axiam client and send verification email
  - `GET /facial_signup/pending` - Show email verification pending page
  - `GET /facial_signup/verify` - Verify email token
  - `GET /facial_signup/qr/:client_id` - Display QR code for facial scan
  - `POST /facial_signup/complete` - Complete signup after facial upload

### 2. Devise Registrations Controller (`app/controllers/users/registrations_controller.rb`)
**Added:**
- `layout 'auth', only: [:new]` - Use auth layout (purple gradient background)
- Override `new` action to display facial signup form

### 3. New Signup View (`app/views/users/registrations/new.html.erb`)
**Created new view based on Signup.html with:**
- Purple gradient background (`linear-gradient(135deg, #667eea 0%, #764ba2 100%)`)
- Clean, modern card design with rounded corners and shadow
- Full name and email input fields
- "Sign Up With Face" button with Axiam logo
- Modal for signup process with status updates
- JavaScript integration with `/facial_signup/create` API
- Email validation (requires valid format: user@domain.com)
- Responsive design

**Flow:**
1. User enters full name and email
2. Clicks "Sign Up With Face" button
3. Modal opens showing "Creating your account..." status
4. JavaScript calls `/facial_signup/create` API endpoint
5. On success: Shows "Check your email" message
6. Redirects to `/facial_signup/pending` page

### 4. Facial Signup Controller Updates (`app/controllers/facial_signup/facial_signup_controller.rb`)
**Changed:**
- Removed `new` action (no longer needed)
- Updated `create` action to return JSON responses instead of redirects:
  - Success: `{ success: true, message: '...', pending_url: '...' }`
  - Error: `{ success: false, error: '...' }` with appropriate HTTP status
- Updated all redirects from `facial_signup_new_path` to `new_user_registration_path`

### 5. View Updates
**Updated files:**
- `app/views/devise/sessions/new.html.erb` - Sign Up link points to `new_user_registration_path`
- `app/views/facial_signup/facial_signup/pending.html.erb` - Back to Signup link
- `app/views/facial_signup/facial_signup/show_qr.html.erb` - Back to signup form link

## URL Changes

| Old URL | New URL | Purpose |
|---------|---------|---------|
| `/facial_signup/new` | `/users/sign_up` | Sign up form |
| `/facial_signup/create` | `/facial_signup/create` | API endpoint (unchanged) |
| `/facial_signup/pending` | `/facial_signup/pending` | Email verification pending (unchanged) |
| `/facial_signup/verify` | `/facial_signup/verify` | Email verification (unchanged) |
| `/facial_signup/qr/:client_id` | `/facial_signup/qr/:client_id` | QR code display (unchanged) |

## Testing

### 1. Access the New Signup Page
```
Development: http://localhost:3030/users/sign_up
Production: https://veritrustai.net/users/sign_up
```

### 2. Test Signup Flow
1. Open browser to `/users/sign_up`
2. Enter full name and email
3. Click "Sign Up With Face"
4. Verify modal shows "Creating your account..." message
5. Check console logs for API response
6. Verify redirect to `/facial_signup/pending` page
7. In development, click the verification link
8. Verify redirect to QR code page
9. Complete facial scan with Axiam mobile app

### 3. Verify Links
- Login page "Sign Up" link → `/users/sign_up` ✅
- Pending page "Back to Signup" → `/users/sign_up` ✅
- QR page "Back to signup form" → `/users/sign_up` ✅

## Design Highlights

### Visual Design (from Signup.html)
- **Background**: Purple gradient (IBM Design inspired)
- **Card**: White card with rounded corners and shadow
- **Typography**: System fonts (-apple-system, BlinkMacSystemFont, Segoe UI)
- **Colors**:
  - Primary Blue: `#0F62FE`
  - Gradient: `#667eea → #764ba2`
  - Text Primary: `#161616`
  - Text Secondary: `#525252`
- **Button**: Gradient blue button with Axiam logo
- **Modal**: Clean modal with status messages and loading spinner

### Responsive Design
- Mobile-friendly with proper padding
- Max width: 28rem (448px)
- Scales gracefully on all screen sizes

## Integration Points

### Frontend → Backend
1. Form submission → JavaScript `fetch()` API call
2. `/facial_signup/create` → Returns JSON response
3. Success → Redirect to pending page
4. Error → Display error message in modal

### Backend Flow (Unchanged)
1. Create Axiam client via `AxiamApi.create_client()`
2. Generate verification token and store in session
3. Send verification email via `FacialSignupMailer`
4. User clicks email link → `/facial_signup/verify`
5. Token validated → Redirect to QR page
6. User scans QR with mobile app
7. Complete facial upload → Create Rails user account

## Files Modified

### New Files
- `app/views/users/registrations/new.html.erb` (587 lines)

### Modified Files
- `config/routes.rb` - Removed GET /facial_signup/new route
- `app/controllers/users/registrations_controller.rb` - Added layout and new action
- `app/controllers/facial_signup/facial_signup_controller.rb` - JSON responses, updated redirects
- `app/views/devise/sessions/new.html.erb` - Updated signup link
- `app/views/facial_signup/facial_signup/pending.html.erb` - Updated back link
- `app/views/facial_signup/facial_signup/show_qr.html.erb` - Updated back link

## Benefits

1. **Rails Convention**: Uses standard Devise `/users/sign_up` URL
2. **Better UX**: Cleaner, more professional design matching Signup.html
3. **Consistent**: Signup and login pages now use same auth layout
4. **API-First**: Backend returns JSON for frontend flexibility
5. **Maintainable**: Separates concerns (view vs API endpoints)

## Migration Notes

- Old `/facial_signup/new` URL will return 404 (route removed)
- All links in the application updated to use `/users/sign_up`
- API endpoints remain unchanged for backward compatibility
- Session handling unchanged - same session variables used

## Next Steps

1. ✅ Test signup flow in development environment
2. ✅ Verify email sending (development shows URL in logs)
3. ✅ Test QR code generation and display
4. ✅ Test mobile app facial scan integration
5. ✅ Verify user account creation after facial upload
6. Deploy to production and update documentation

---

**Date**: November 25, 2025  
**Version**: 1.0  
**Status**: ✅ Complete
