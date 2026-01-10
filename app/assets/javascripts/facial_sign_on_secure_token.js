// Facial Sign-On Secure Token Fetcher
// SECURITY FIX: Fetch verification token via CSRF-protected API instead of inline HTML

/**
 * Fetch verification token securely from session-based API endpoint
 * @returns {Promise<{success: boolean, token?: string, expires_in?: number, error?: string}>}
 */
async function fetchVerificationTokenSecurely() {
  try {
    // Get CSRF token from meta tag (Rails default)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    
    if (!csrfToken) {
      console.error('[FacialSignOn] CSRF token not found in page');
      return {
        success: false,
        error: 'CSRF token missing. Please refresh the page.'
      };
    }

    const response = await fetch('/facial_sign_on/get_verification_token', {
      method: 'GET',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      },
      credentials: 'same-origin'  // Include session cookies
    });

    const data = await response.json();

    if (!response.ok) {
      return {
        success: false,
        error: data.user_message || data.error || 'Failed to fetch verification token'
      };
    }

    if (!data.verification_token) {
      return {
        success: false,
        error: 'No verification token in response'
      };
    }

    return {
      success: true,
      token: data.verification_token,
      expires_in: data.expires_in,
      expires_at: data.expires_at
    };

  } catch (error) {
    console.error('[FacialSignOn] Exception fetching token:', error);
    return {
      success: false,
      error: `Network error: ${error.message}`
    };
  }
}

/**
 * Initialize Facial Sign-On with secure token delivery
 * Replaces the old pattern of inline HTML token exposure
 * 
 * @param {Object} axiamClient - Initialized AxiamActionCableClient instance
 * @param {Function} onMessage - Callback for received messages
 * @param {Function} onError - Callback for errors (optional)
 * @returns {Promise<boolean>} Success status
 */
async function initSecureFacialSignOn(axiamClient, onMessage, onError = null) {
  try {
    // 1. Fetch token securely via API
    const tokenResult = await fetchVerificationTokenSecurely();
    
    if (!tokenResult.success) {
      const errorMsg = tokenResult.error || 'Failed to get verification token';
      console.error('[FacialSignOn] Init failed:', errorMsg);
      
      if (onError) {
        onError(errorMsg);
      } else {
        alert(errorMsg);
      }
      
      return false;
    }

    // 2. Subscribe to ActionCable channel with fetched token
    
    axiamClient.subscribeFacialSignOn(tokenResult.token, {
      onMessage: (data) => {
        if (onMessage) {
          onMessage(data);
        }
      },
      onConnected: () => {
        // Connected to ActionCable
      },
      onDisconnected: () => {
        // Disconnected from ActionCable
      }
    });

    return true;

  } catch (error) {
    console.error('[FacialSignOn] Exception during init:', error);
    
    if (onError) {
      onError(`Initialization error: ${error.message}`);
    } else {
      alert(`Error: ${error.message}`);
    }
    
    return false;
  }
}

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    fetchVerificationTokenSecurely,
    initSecureFacialSignOn
  };
}

// Make available globally for browser usage
if (typeof window !== 'undefined') {
  window.FacialSignOnSecure = {
    fetchToken: fetchVerificationTokenSecurely,
    init: initSecureFacialSignOn
  };
}
