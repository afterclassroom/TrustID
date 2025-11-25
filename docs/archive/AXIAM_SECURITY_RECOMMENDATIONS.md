# Security Review & Recommendations for axiam-actioncable-client.js

**To:** Axiam Development Team  
**From:** Axiam Web Client Integration Team  
**Date:** November 3, 2025  
**Subject:** Critical Security Issues & Recommended Updates for ActionCable Client Library

---

## Executive Summary

During integration of the Axiam Facial Sign-On service, we identified **critical security vulnerabilities** in the provided `axiam-actioncable-client.js` library that expose sensitive credentials to end-user browsers. We have implemented workarounds on our side, but **these issues require fixes in the Axiam client library** to protect all integrators.

**Risk Level:** 🔴 **HIGH** - Credentials exposure, token hijacking, replay attacks

---

## 🔴 Critical Security Issues Identified

### Issue #1: Redis Credentials Exposed to Browser

**Current Implementation:**
```javascript
// axiam-actioncable-client.js (line ~21-24)
const { redis_username, redis_password, channel_prefix } = this.siteCredentials;

const cableUrl = `${this.serverUrl}?redis_username=${encodeURIComponent(redis_username)}&redis_password=${encodeURIComponent(redis_password)}&channel_prefix=${encodeURIComponent(channel_prefix)}`;
```

**Problem:**
- ❌ `redis_username` and `redis_password` are **sent over the network** in WebSocket URL
- ❌ Visible in browser DevTools → Network tab → WebSocket connection
- ❌ Visible in JavaScript source code (even minified)
- ❌ Can be extracted by malicious users or browser extensions

**Impact:**
- Attackers can extract Redis credentials from any client browser
- Direct access to Redis server if not properly firewalled
- Potential to read/write/delete all cached data
- Complete compromise of multi-tenant isolation

**Severity:** 🔴 **CRITICAL**

---

### Issue #2: No Server-Side Authorization for Subscriptions

**Current Implementation:**
```javascript
// Client can subscribe to ANY channel by knowing the token
axiamClient.subscribeFacialSignOn('any_stolen_token', { ... });
```

**Problem:**
- ❌ No server-side validation of subscription requests
- ❌ Anyone with a verification token can subscribe (even expired/used tokens)
- ❌ No check if the token belongs to the current user session
- ❌ Tokens visible in HTML source or Network responses can be hijacked

**Impact:**
- Attacker can intercept authentication messages for other users
- Replay attacks using stolen tokens
- Man-in-the-middle attacks on facial authentication flow

**Severity:** 🔴 **HIGH**

---

### Issue #3: Verification Tokens Exposed in Client-Side HTML

**Current Pattern (from integration docs):**
```erb
<!-- In Rails view -->
<script>
  const token = '<%= @verification_token %>';  // ❌ Exposed in HTML source
  subscribeFacialSignOn(token);
</script>
```

**Problem:**
- ❌ Tokens visible in "View Page Source"
- ❌ No expiration mechanism enforced client-side
- ❌ Can be copied and reused by attackers

**Impact:**
- Session hijacking
- Unauthorized access to facial authentication flow
- Replay attacks

**Severity:** 🔴 **HIGH**

---

## ✅ Recommended Solutions

### Solution #1: Remove Redis Credentials from Client Library

**Recommended Change:**

```javascript
// OLD (insecure):
const { redis_username, redis_password, channel_prefix } = this.siteCredentials;
const cableUrl = `${this.serverUrl}?redis_username=${...}&redis_password=${...}&channel_prefix=${...}`;

// NEW (secure):
const { channel_prefix } = this.siteCredentials;
const cableUrl = `${this.serverUrl}?channel_prefix=${encodeURIComponent(channel_prefix)}`;
// Redis authentication should happen SERVER-SIDE during WebSocket handshake
```

**Implementation Notes:**
1. **Server-side authentication:** ActionCable server should authenticate to Redis using credentials stored securely on the server (environment variables, encrypted config).
2. **Client only needs:** `channel_prefix` for routing and `server_url` for connection.
3. **Backward compatibility:** Can support both patterns temporarily with a deprecation warning.

**Benefits:**
- ✅ Zero sensitive data exposed to browser
- ✅ No credential leakage risk
- ✅ Simpler client integration

---

### Solution #2: Server-Side Subscription Authorization

**Recommended Server Implementation:**

```ruby
# app/channels/facial_sign_on_login_channel.rb
class FacialSignOnLoginChannel < ApplicationCable::Channel
  def subscribed
    token = params[:token]
    
    # 1. Validate token exists and not expired (use cache/database)
    cached_token = Rails.cache.read("facial_token:#{token}")
    unless cached_token
      Rails.logger.warn "[Security] Rejected subscription: invalid/expired token"
      reject
      return
    end
    
    # 2. Optional: Verify token belongs to current session/user
    # unless cached_token[:session_id] == request.session.id
    #   reject
    #   return
    # end
    
    # 3. Mark token as used (one-time use, prevent replay attacks)
    Rails.cache.delete("facial_token:#{token}")
    
    # 4. Subscribe to channel
    channel_name = "#{channel_prefix}:facial_sign_on_login_#{token}"
    stream_from channel_name
  end
end
```

**Client-side changes:** None required (transparent to client)

**Benefits:**
- ✅ Prevents unauthorized subscriptions
- ✅ One-time use tokens (anti-replay)
- ✅ Server enforces all authorization logic
- ✅ Audit trail of rejected subscriptions

---

### Solution #3: Secure Token Delivery Pattern

**Current (Insecure):**
```erb
<script>
  const token = '<%= @verification_token %>';  // ❌ In HTML
</script>
```

**Recommended (Secure):**

**Option A: Session-based (Recommended)**
```ruby
# Controller: Store token in session, not view
def push_notification
  result = AxiamApi.push_notification(...)
  if result['verification_token']
    session[:facial_verification_token] = result['verification_token']
    session[:facial_verification_expires_at] = 5.minutes.from_now.to_i
    # Also cache for subscription validation
    Rails.cache.write("facial_token:#{result['verification_token']}", 
                      { user_id: current_user&.id }, 
                      expires_in: 5.minutes)
  end
  render :subscribe
end

# API endpoint: Fetch token via AJAX with CSRF protection
def get_verification_token
  token = session[:facial_verification_token]
  expires_at = session[:facial_verification_expires_at]
  
  if token.present? && Time.now.to_i < expires_at
    render json: { token: token, expires_in: expires_at - Time.now.to_i }
  else
    render json: { error: 'Token expired' }, status: :unauthorized
  end
end
```

```javascript
// Client: Fetch token via API (not inline HTML)
async function initFacialSignOn() {
  const response = await fetch('/facial_sign_on/get_token', {
    headers: { 'X-CSRF-Token': csrfToken }
  });
  const { token } = await response.json();
  subscribeFacialSignOn(token);
}
```

**Option B: Short-lived JWT (Alternative)**
```ruby
# Sign token with server secret
payload = { 
  verification_token: result['verification_token'],
  exp: 5.minutes.from_now.to_i,
  user_id: current_user&.id
}
jwt_token = JWT.encode(payload, Rails.application.secret_key_base)

# Client receives JWT, server validates on subscription
```

**Benefits:**
- ✅ Tokens not visible in HTML source
- ✅ CSRF protection on token fetch
- ✅ Explicit expiration enforcement
- ✅ Can rotate/invalidate tokens server-side

---

## 📋 Recommended Library API Changes

### Current API (Insecure):
```javascript
const siteCredentials = {
  redis_username: 'app_73075ebd7c6cb17c',  // ❌ Should NOT be client-side
  redis_password: 'b911df4b19034f5a75e46879a4525fdc',  // ❌ CRITICAL
  channel_prefix: 'ch_984ab6aee2cd'
};

const axiamClient = new AxiamActionCableClient({
  siteCredentials,
  serverUrl: 'ws://localhost:3000/cable'
});
```

### Recommended API (Secure):
```javascript
// Only public routing information
const siteCredentials = {
  channel_prefix: 'ch_984ab6aee2cd'  // ✅ Public routing info only
};

const axiamClient = new AxiamActionCableClient({
  siteCredentials,
  serverUrl: 'wss://axiam.io/cable'  // ✅ Server handles authentication
});

// Token obtained securely via API
const token = await fetchVerificationToken();  // CSRF-protected endpoint
axiamClient.subscribeFacialSignOn(token, {
  onMessage: (data) => { /* ... */ }
});
```

---

## 🔒 Additional Security Recommendations

### 1. Use WSS (WebSocket Secure) in Production
```javascript
// Enforce HTTPS/WSS
if (production && !serverUrl.startsWith('wss://')) {
  throw new Error('Production must use WSS (secure WebSocket)');
}
```

### 2. Add Connection Timeout & Retry Limits
```javascript
const MAX_RETRIES = 3;
const CONNECTION_TIMEOUT = 10000; // 10 seconds

async connect() {
  // Add timeout and retry logic to prevent indefinite hanging
  return Promise.race([
    this.attemptConnection(),
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Connection timeout')), CONNECTION_TIMEOUT)
    )
  ]);
}
```

### 3. Add CSRF Token Support for WebSocket Handshake
```javascript
// Include CSRF token in connection params
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
const cableUrl = `${this.serverUrl}?channel_prefix=${channel_prefix}&csrf_token=${csrfToken}`;
```

### 4. Add Security Headers Documentation
Recommend integrators set these headers:
```nginx
# Nginx config
add_header Content-Security-Policy "connect-src 'self' wss://axiam.io;";
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
```

### 5. Rate Limiting for Subscriptions
Server-side implementation to prevent abuse:
```ruby
# Limit subscription attempts per IP/session
class FacialSignOnLoginChannel < ApplicationCable::Channel
  def subscribed
    rate_key = "sub_attempt:#{request.remote_ip}"
    attempts = Rails.cache.increment(rate_key, 1, expires_in: 1.minute)
    
    if attempts > 10
      Rails.logger.warn "[Security] Rate limit exceeded for #{request.remote_ip}"
      reject
      return
    end
    
    # ... rest of subscription logic
  end
end
```

---

## 📊 Impact Assessment

### Current Risk Exposure
- **All Axiam integrators** using the current library are exposed
- **Redis credentials** potentially leaked to ~X users (multiply by number of clients)
- **Verification tokens** can be harvested and reused

### Benefits of Proposed Changes
| Metric | Current | After Fix | Improvement |
|--------|---------|-----------|-------------|
| Credentials in browser | ❌ Yes (redis user/pass) | ✅ No | 100% |
| Token hijacking risk | 🔴 High | 🟢 Low | ~90% |
| Replay attack prevention | ❌ None | ✅ One-time use | 100% |
| Server-side control | 🟡 Partial | ✅ Full | ~80% |
| Compliance (GDPR, SOC2) | ❌ Non-compliant | ✅ Compliant | ✓ |

---

## 🛠️ Implementation Roadmap

### Phase 1: Immediate (Critical Fixes)
**Timeline:** 1-2 weeks

1. ✅ Remove `redis_username` and `redis_password` from client library
2. ✅ Update server to authenticate Redis connections server-side
3. ✅ Add server-side subscription authorization
4. ✅ Implement one-time use tokens with cache validation

### Phase 2: Enhanced Security
**Timeline:** 2-4 weeks

1. ✅ Session-based or JWT token delivery pattern
2. ✅ CSRF protection for token endpoints
3. ✅ Rate limiting for subscriptions
4. ✅ Connection timeout and retry logic

### Phase 3: Documentation & Migration
**Timeline:** 1-2 weeks

1. ✅ Update integration docs with secure patterns
2. ✅ Provide migration guide for existing clients
3. ✅ Deprecation warnings for old API
4. ✅ Security best practices guide

### Phase 4: Compliance & Audit
**Timeline:** Ongoing

1. ✅ Security audit of entire facial sign-on flow
2. ✅ Penetration testing
3. ✅ SOC2 / ISO27001 compliance verification
4. ✅ Bug bounty program consideration

---

## 📚 Reference Implementation

We have implemented the recommended security fixes on our side as a workaround:

**Files modified:**
- `app/helpers/application_helper.rb` - Only expose public credentials
- `app/controllers/facial_sign_on_controller.rb` - Session-based token storage + cache
- `app/channels/facial_sign_on_login_channel.rb` - Server-side validation + one-time use
- `app/assets/javascripts/facial_sign_on_login_channel.js` - Removed Redis creds requirement
- `app/assets/javascripts/axiam-actioncable-client.js` - Use only channel_prefix

**Our workaround code is available for reference** if the Axiam team needs examples.

---

## 💬 Questions & Next Steps

### Questions for Axiam Team

1. **Timeline:** When can we expect a patched version of `axiam-actioncable-client.js`?
2. **Breaking changes:** Will this be a major version bump? Do we need migration time?
3. **Backward compatibility:** Can you support both old and new patterns temporarily?
4. **Security disclosure:** Should we coordinate responsible disclosure with other clients?
5. **Audit:** Has Axiam performed a security audit of the ActionCable integration?

### Proposed Meeting

We recommend a **technical security review meeting** with:
- Axiam backend/security team
- Our integration team
- Topics: Architecture review, fix implementation, migration strategy

**Availability:** We can meet this week or next.

---

## 🔗 Appendix

### A. Attack Scenarios

**Scenario 1: Credential Theft**
1. User opens facial sign-on page
2. Malicious browser extension reads `window.SITE_CREDENTIALS`
3. Extracts `redis_username` and `redis_password`
4. Connects directly to Redis (if accessible)
5. Reads/modifies/deletes all cached tokens

**Scenario 2: Token Replay**
1. User A initiates facial sign-on, gets token `abc123`
2. Attacker intercepts token from Network tab or HTML source
3. Attacker subscribes to channel with stolen token
4. Attacker receives authentication confirmation
5. Attacker completes login as User A

**Scenario 3: Multi-Tenant Data Leak**
1. Attacker extracts `channel_prefix` for Tenant A
2. Guesses or brute-forces verification tokens
3. Subscribes to other users' authentication channels
4. Intercepts facial authentication data

### B. Compliance Implications

**GDPR (EU):**
- Article 32: Security of processing requires "appropriate technical measures"
- Exposed credentials = potential data breach notification requirement

**SOC 2 (Type II):**
- CC6.1: Logical and physical access controls
- Credentials in browser = control failure

**PCI DSS (if processing payments):**
- Requirement 6.5: Prevent common vulnerabilities
- Exposed secrets = immediate fail

### C. Industry Standards

**OWASP Top 10:**
- A01:2021 – Broken Access Control ✓ (no subscription auth)
- A02:2021 – Cryptographic Failures ✓ (credentials in transit)
- A07:2021 – Identification and Authentication Failures ✓ (token replay)

**CWE (Common Weakness Enumeration):**
- CWE-312: Cleartext Storage of Sensitive Information
- CWE-319: Cleartext Transmission of Sensitive Information
- CWE-798: Use of Hard-coded Credentials

---

## 📞 Contact

For questions or to schedule a security review meeting:

**Technical Contact:**  
[Your Name / Team]  
Email: [contact email]  
Slack: [if applicable]

**Urgency:** 🔴 High - Please respond within 48 hours

---

**Thank you for your attention to these critical security issues. We look forward to working together to secure the Axiam Facial Sign-On integration for all clients.**

---

*Document Version: 1.0*  
*Date: November 3, 2025*  
*Classification: Confidential - Security Review*
