# Facial Signup Flow - Email Verification Implementation

**Updated:** November 20, 2025

## 📋 Complete Workflow

```
Step 1: User visits /facial_signup/new
        ↓
Step 2: User submits form (email + full_name)
        POST /facial_signup/create
        ↓
Step 3: Backend calls Axiam API
        POST /api/v1/facial_sign_on/client/create
        Response: { client_id, site_id }
        ↓
Step 4: Generate verification token
        Store in session with 1-hour expiration
        ↓
Step 5: Send verification email
        FacialSignupMailer.verification_email()
        ↓
Step 6: Redirect to /facial_signup/pending
        "Check your email" page
        ↓
Step 7: User opens email
        Clicks "Verify Email Address" button
        ↓
Step 8: User clicks verification link
        GET /facial_signup/verify?token=xxx
        ↓
Step 9: Backend validates token
        - Check token matches session
        - Check not expired (1 hour)
        - Delete token from session
        ↓
Step 10: Redirect to /facial_signup/qr/:client_id
         Generate QR code with action=signup
         ↓
Step 11: Display QR code
         Subscribe to ActionCable
         ↓
Step 12: User scans QR with Axiam app
         ↓
Step 13: WebSocket Event 1: Device Registered
         { registered: true, action: 'signup' }
         ↓
Step 14: User captures facial on mobile
         ↓
Step 15: WebSocket Event 2: Facial Uploaded
         { status: 'uploaded', action: 'signup' }
         ↓
Step 16: Show success message
         Redirect to login page
```

---

## 🗂 Files Created/Modified

### Controllers
- **`app/controllers/facial_signup/facial_signup_controller.rb`**
  - `new` - Display signup form
  - `create` - Create client, send verification email
  - `pending` - "Check your email" page
  - `verify` - Validate token and redirect to QR
  - `show_qr` - Display QR code and handle WebSocket

### Routes (`config/routes.rb`)
```ruby
namespace :facial_signup do
  get 'new'                    # /facial_signup/new
  post 'create'                # /facial_signup/create
  get 'pending'                # /facial_signup/pending
  get 'verify'                 # /facial_signup/verify?token=xxx
  get 'qr/:client_id'          # /facial_signup/qr/:client_id
end
```

### Mailers
- **`app/mailers/facial_signup_mailer.rb`**
  - `verification_email(email:, full_name:, verification_url:)`

### Email Templates
- **`app/views/facial_signup_mailer/verification_email.html.erb`**
  - Beautiful HTML email with gradient header
  - Verify button with call-to-action
  - Alternative text link (for email clients without buttons)
  - Expiration warning (1 hour)
  - Step-by-step instructions

- **`app/views/facial_signup_mailer/verification_email.text.erb`**
  - Plain text version for email clients

### Views
- **`app/views/facial_signup/facial_signup/new.html.erb`**
  - Signup form (email + full name)
  - Benefits section
  - Privacy box
  - Link to login

- **`app/views/facial_signup/facial_signup/pending.html.erb`**
  - "Check your email" message
  - Email address display
  - Next steps instructions
  - Expiration warning
  - Back to signup / Login links

- **`app/views/facial_signup/facial_signup/show_qr.html.erb`**
  - QR code display
  - Status indicators (Waiting → Processing → Success)
  - ActionCable WebSocket integration
  - Mobile instructions
  - SweetAlert2 notifications

### Mailer Previews
- **`test/mailers/previews/facial_signup_mailer_preview.rb`**
  - Preview verification email at: `http://localhost:3030/rails/mailers/facial_signup_mailer`

---

## 🔒 Security Features

### 1. Verification Token
```ruby
# Generate secure random token
verification_token = SecureRandom.urlsafe_base64(32)

# Store in session with expiration
session[:facial_signup_verification_token] = verification_token
session[:facial_signup_token_expires_at] = 1.hour.from_now.to_i
```

### 2. Token Validation
```ruby
# Check token match
session[:facial_signup_verification_token] == params[:token]

# Check expiration
Time.now.to_i > session[:facial_signup_token_expires_at]

# Delete after use (one-time use)
session.delete(:facial_signup_verification_token)
```

### 3. Session Management
- Client ID stored in session
- Site ID stored in session
- Email and full name stored temporarily
- All cleared after signup completion

---

## 📧 Email Configuration

### Development (Letter Opener)
Add to `config/environments/development.rb`:
```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: 'localhost', port: 3030 }
```

### Production (SMTP)
Add to `config/environments/production.rb`:
```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.perform_deliveries = true
config.action_mailer.default_url_options = { host: 'webclient.axiam.io', protocol: 'https' }

config.action_mailer.smtp_settings = {
  address: ENV['SMTP_ADDRESS'],
  port: ENV['SMTP_PORT'],
  domain: ENV['SMTP_DOMAIN'],
  user_name: ENV['SMTP_USERNAME'],
  password: ENV['SMTP_PASSWORD'],
  authentication: 'plain',
  enable_starttls_auto: true
}
```

### Environment Variables
```bash
# .env or config/application.yml
MAILER_FROM=noreply@axiam.io
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=axiam.io
SMTP_USERNAME=your_email@gmail.com
SMTP_PASSWORD=your_app_password
```

---

## 🎨 Email Design Features

### HTML Email
- ✅ Gradient header (teal → green)
- ✅ Large "Verify Email Address" button
- ✅ Expiration warning box
- ✅ Alternative text link (for accessibility)
- ✅ Step-by-step next steps
- ✅ Footer with copyright and support link
- ✅ Responsive design (mobile-friendly)

### Text Email
- ✅ Plain text version
- ✅ All essential information
- ✅ Direct verification link
- ✅ Step-by-step instructions

---

## 🧪 Testing

### 1. Preview Email in Browser
```
Visit: http://localhost:3030/rails/mailers/facial_signup_mailer/verification_email
```

### 2. Test Complete Flow
```bash
# 1. Start Rails server
docker compose up

# 2. Visit signup page
http://localhost:3030/facial_signup/new

# 3. Submit form
# - Email: test@example.com
# - Full Name: Test User

# 4. Check terminal/letter_opener for email

# 5. Click verification link in email

# 6. Scan QR code with Axiam app

# 7. Complete facial capture

# 8. Should redirect to login page
```

### 3. Test Token Expiration
```ruby
# In Rails console
rails c

# Manually expire token
session = ActionDispatch::Request::Session.new({})
session[:facial_signup_token_expires_at] = 2.hours.ago.to_i

# Try to verify - should fail with "expired" message
```

---

## 🔧 Troubleshooting

### Issue: Email not sent
**Solution:**
1. Check `config/environments/development.rb` has mailer settings
2. Check logs: `docker compose logs -f web`
3. Verify Letter Opener gem is installed: `bundle list | grep letter_opener`

### Issue: Verification link doesn't work
**Solution:**
1. Check token in session matches URL token
2. Verify token hasn't expired (1 hour limit)
3. Check Rails logs for detailed error

### Issue: "Session expired" error
**Solution:**
1. Don't clear cookies between signup and verification
2. Ensure session store is working (check `config/initializers/session_store.rb`)
3. Increase session expiration if needed

---

## 📊 Database Considerations

**Note:** Current implementation uses **session storage only**. No database writes until facial upload completes.

**Future Enhancement:** Consider creating `pending_signups` table:
```ruby
# Migration example (future)
create_table :pending_signups do |t|
  t.string :client_id, null: false, index: { unique: true }
  t.string :site_id
  t.string :email, null: false
  t.string :full_name
  t.string :verification_token, index: { unique: true }
  t.datetime :token_expires_at
  t.boolean :email_verified, default: false
  t.boolean :facial_uploaded, default: false
  t.timestamps
end
```

---

## 🚀 Deployment Checklist

Before deploying to production:

1. ✅ Set `MAILER_FROM` environment variable
2. ✅ Configure SMTP settings (Gmail/SendGrid/AWS SES)
3. ✅ Set correct `default_url_options` host
4. ✅ Test email delivery in staging
5. ✅ Verify verification links work across environments
6. ✅ Check email appears correct in various email clients (Gmail, Outlook, Apple Mail)
7. ✅ Test spam folder delivery
8. ✅ Enable email logging/monitoring
9. ✅ Set up email delivery error alerts

---

## 📝 API Endpoints Used

### 1. Create Client
```
POST /api/v1/facial_sign_on/client/create
Authorization: Bearer {authenticated_token}

Body:
{
  "email": "user@example.com",
  "full_name": "John Doe"
}

Response:
{
  "success": true,
  "data": {
    "client_id": "uuid-here",
    "site_id": "uuid-here",
    "email": "user@example.com",
    "full_name": "John Doe"
  }
}
```

### 2. Generate QR Code
```
POST /api/v1/facial_sign_on/client/qrcode
Authorization: Bearer {authenticated_token}

Body:
{
  "id": "client-uuid",
  "action": "signup"
}

Response:
{
  "success": true,
  "data": {
    "qrcode_base64": "iVBORw0KGgo..."
  }
}
```

---

## 🎯 Next Steps

1. **Test email delivery** with real SMTP provider
2. **Customize email template** with your branding
3. **Add resend verification** feature
4. **Implement rate limiting** on email sending
5. **Add email open tracking** (optional)
6. **Create user account** when facial upload completes
7. **Send welcome email** after successful signup

---

**End of Document**
