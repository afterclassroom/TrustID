// Axiam Integration Helpers (v2.0 - November 2025)
// 
// This file provides helper functions for Axiam facial sign-on integration
// following the security architecture recommended by Axiam in November 2025.
//
// Key Security Features:
// - No Redis credentials in client-side code
// - Environment-aware ActionCable URLs
// - Secure token delivery via CSRF-protected API
// - One-time use tokens with server-side validation

/**
 * Get environment-aware ActionCable URL
 * 
 * Automatically detects the current environment and returns
 * the appropriate WebSocket URL for Axiam ActionCable server.
 * 
 * @returns {string} WebSocket URL (ws:// or wss://)
 * 
 * @example
 * const url = getActionCableUrl();
 * // Development: "ws://localhost:3000/cable"
 * // Staging: "wss://staging.axiam.io/cable"
 * // Production: "wss://axiam.io/cable"
 */
function getActionCableUrl() {
  const hostname = window.location.hostname;
  
  // Development environment (localhost or 127.0.0.1)
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return 'ws://localhost:3000/cable';
  }
  
  // Staging environment (any hostname containing 'staging')
  if (hostname.includes('staging')) {
    return 'wss://staging.axiam.io/cable';
  }
  
  // Production environment (default)
  return 'wss://axiam.io/cable';
}

/**
 * Validate that site credentials are properly configured
 * 
 * Checks that window.SITE_CREDENTIALS exists and contains
 * only the expected public fields (no sensitive data).
 * 
 * @returns {boolean} True if credentials are valid and secure
 * 
 * @example
 * if (validateSiteCredentials()) {
 *   console.log('✅ Credentials are secure');
 * } else {
 *   console.error('❌ Credentials missing or insecure');
 * }
 */
function validateSiteCredentials() {
  if (!window.SITE_CREDENTIALS) {
    console.error('❌ [Security] SITE_CREDENTIALS not found in window object');
    return false;
  }
  
  const creds = window.SITE_CREDENTIALS;
  
  // Check required fields
  if (!creds.channel_prefix) {
    console.error('❌ [Security] channel_prefix missing from SITE_CREDENTIALS');
    return false;
  }
  
  if (!creds.server_url) {
    console.error('❌ [Security] server_url missing from SITE_CREDENTIALS');
    return false;
  }
  
  // Security check: Ensure Redis credentials are NOT exposed
  if (creds.redis_username || creds.redis_password) {
    console.error('🔴 [CRITICAL SECURITY ISSUE] Redis credentials exposed in client-side code!');
    console.error('This is a CRITICAL security vulnerability. Please check:');
    console.error('1. app/helpers/application_helper.rb → axiam_credentials_js method');
    console.error('2. app/views/layouts/application.html.erb → window.SITE_CREDENTIALS');
    console.error('Redis credentials should ONLY be in axiam_credentials_full (server-side).');
    return false;
  }
  
  return true;
}

/**
 * Check if AxiamActionCableClient is properly initialized
 * 
 * @returns {boolean} True if client is initialized and connected
 */
function isAxiamClientReady() {
  return !!(
    window.App && 
    window.App.axiamClient && 
    typeof window.App.axiamClient.isConnected === 'function' &&
    window.App.axiamClient.isConnected()
  );
}

/**
 * Wait for AxiamActionCableClient to be ready
 * 
 * Returns a promise that resolves when the client is initialized and connected.
 * Useful for ensuring client is ready before subscribing to channels.
 * 
 * @param {number} timeout - Maximum time to wait in milliseconds (default: 10000)
 * @returns {Promise<boolean>} Resolves to true when ready, rejects on timeout
 * 
 * @example
 * await waitForAxiamClient();
 * console.log('Client is ready, can now subscribe to channels');
 */
function waitForAxiamClient(timeout = 10000) {
  return new Promise((resolve, reject) => {
    // Check if already ready
    if (isAxiamClientReady()) {
      resolve(true);
      return;
    }
    
    // Wait for initialization
    const startTime = Date.now();
    const checkInterval = setInterval(() => {
      if (isAxiamClientReady()) {
        clearInterval(checkInterval);
        resolve(true);
      } else if (Date.now() - startTime > timeout) {
        clearInterval(checkInterval);
        reject(new Error('AxiamActionCableClient initialization timeout'));
      }
    }, 100);
  });
}

/**
 * Show a status message to the user
 * 
 * Helper function to display Bootstrap-styled alert messages.
 * 
 * @param {string} elementId - ID of the container element
 * @param {string} message - Message to display
 * @param {string} type - Alert type: 'success', 'danger', 'warning', 'info'
 * @param {boolean} showRetry - Whether to show a retry link (default: false)
 * 
 * @example
 * showStatusMessage('subscribe-status', 'Connected successfully', 'success');
 * showStatusMessage('login-error', 'Connection failed', 'danger', true);
 */
function showStatusMessage(elementId, message, type = 'info', showRetry = false) {
  const element = document.getElementById(elementId);
  if (!element) {
    console.warn(`Element with ID "${elementId}" not found`);
    return;
  }
  
  const alertClass = 'alert-' + type;
  const retryLink = showRetry 
    ? '<br><a href="/facial_sign_on/login" class="alert-link">Try again</a>' 
    : '';
  
  element.innerHTML = `
    <div class="alert ${alertClass}" role="alert">
      ${message}
      ${retryLink}
    </div>
  `;
}

/**
 * Log Axiam events with consistent formatting
 * 
 * @param {string} level - Log level: 'info', 'warn', 'error', 'debug'
 * @param {string} message - Log message
 * @param {object} data - Additional data to log (optional)
 */
function logAxiamEvent(level, message, data = null) {
  const prefix = '[Axiam]';
  const timestamp = new Date().toISOString();
  
  const logMessage = `${prefix} [${timestamp}] ${message}`;
  
  switch (level) {
    case 'info':
      console.info(logMessage, data || '');
      break;
    case 'warn':
      console.warn(logMessage, data || '');
      break;
    case 'error':
      console.error(logMessage, data || '');
      break;
    case 'debug':
      if (window.AXIAM_DEBUG_MODE) {
      }
      break;
    default:
  }
}

/**
 * Get CSRF token from meta tag
 * 
 * @returns {string|null} CSRF token or null if not found
 */
function getCsrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]');
  if (!meta) {
    console.error('❌ CSRF token meta tag not found');
    return null;
  }
  return meta.content;
}

/**
 * Initialize Axiam integration with automatic environment detection
 * 
 * This is a convenience wrapper that:
 * 1. Validates site credentials
 * 2. Detects environment
 * 3. Initializes AxiamActionCableClient
 * 4. Returns the configured client instance
 * 
 * @returns {Promise<AxiamActionCableClient>} Configured and connected client
 * 
 * @example
 * const client = await initializeAxiamIntegration();
 * client.subscribeFacialSignOn(token, callbacks);
 */
async function initializeAxiamIntegration() {
  // Step 1: Validate credentials
  if (!validateSiteCredentials()) {
    throw new Error('Invalid or insecure site credentials configuration');
  }
  
  // Step 2: Get environment-specific URL
  const serverUrl = getActionCableUrl();
  logAxiamEvent('info', `Detected environment URL: ${serverUrl}`);
  
  // Step 3: Initialize client if needed
  if (typeof window.initAxiamClientIfNeeded === 'function') {
    await window.initAxiamClientIfNeeded();
  }
  
  // Step 4: Wait for client to be ready
  await waitForAxiamClient();
  
  // Step 5: Return client instance
  if (!window.App || !window.App.axiamClient) {
    throw new Error('AxiamActionCableClient initialization failed');
  }
  
  logAxiamEvent('info', 'Axiam integration initialized successfully');
  return window.App.axiamClient;
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    getActionCableUrl,
    validateSiteCredentials,
    isAxiamClientReady,
    waitForAxiamClient,
    showStatusMessage,
    logAxiamEvent,
    getCsrfToken,
    initializeAxiamIntegration
  };
}

// Make available globally for browser usage
if (typeof window !== 'undefined') {
  window.AxiamHelpers = {
    getActionCableUrl,
    validateSiteCredentials,
    isAxiamClientReady,
    waitForAxiamClient,
    showStatusMessage,
    logAxiamEvent,
    getCsrfToken,
    initializeAxiamIntegration
  };
  
  // Auto-validate on page load (development mode only)
  if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    document.addEventListener('DOMContentLoaded', function() {
      if (window.SITE_CREDENTIALS) {
        validateSiteCredentials();
      }
    });
  }
}
