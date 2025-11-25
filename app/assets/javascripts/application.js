//= require rails-ujs
//= require popper
//= require bootstrap

// Axiam ActionCable Integration (v2.0 - November 2025 Security Update)
// Load order is important:
// 1. ActionCable core library
// 2. Axiam helper utilities (environment detection, validation)
// 3. Axiam ActionCable client (multi-tenant WebSocket client)
// 4. Secure token fetcher (CSRF-protected API)
// 5. Facial sign-on channel logic

//= require actioncable
//= require_self

// Axiam integration libraries (v2.0 - Secure)
//= require axiam_helpers
//= require axiam-actioncable-client
//= require facial_sign_on_secure_token
//= require facial_sign_on_login_channel

// VeriTrust shared utilities and navigation
//= require veritrust

// VeriTrust home page verification features
//= require home_verification

// Other application scripts
//= require_tree .