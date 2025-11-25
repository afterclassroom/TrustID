// ActionCable Multi-Tenant Client Helper
class AxiamActionCableClient {
  constructor(options = {}) {
    // Check if ActionCable is available
    if (typeof ActionCable === 'undefined') {
      throw new Error('ActionCable is required but not available. Please load ActionCable first.');
    }
    
    this.siteCredentials = options.siteCredentials;
    this.serverUrl = options.serverUrl || 'ws://localhost:3000/cable';
    this.cable = null;
    this.subscriptions = new Map();
  }

  // Initialize connection với site credentials
  async connect() {
    if (!this.siteCredentials) {
      throw new Error('Site credentials required');
    }

    const { channel_prefix } = this.siteCredentials;
    
    // SECURITY FIX: Only send channel_prefix (public routing info)
    // Redis username/password are NEVER sent from browser - they stay server-side
    if (!channel_prefix) {
      throw new Error('channel_prefix is required');
    }
    
    // Connect with only public channel prefix
    const cableUrl = `${this.serverUrl}?channel_prefix=${encodeURIComponent(channel_prefix)}`;
    
    this.cable = ActionCable.createConsumer(cableUrl);
    this.channelPrefix = channel_prefix;
    
    return new Promise((resolve, reject) => {
      // Force connection open
      this.cable.connection.open();
      
      // Check connection state periodically (same logic as working test)
      const checkConnection = () => {
        const conn = this.cable.connection;
        if (conn.webSocket && conn.webSocket.readyState === 1) {
          resolve(this.cable);
          return true;
        }
        return false;
      };
      
      // Check immediately
      setTimeout(checkConnection, 1000);
      
      // Check every second for up to 10 seconds
      let checks = 0;
      const interval = setInterval(() => {
        checks++;
        if (checkConnection()) {
          clearInterval(interval);
        } else if (checks >= 10) {
          reject(new Error('ActionCable connection timeout'));
          clearInterval(interval);
        }
      }, 1000);
    });
  }

  // Subscribe to channel với automatic prefix
  subscribe(channelName, options = {}) {
    if (!this.cable) {
      throw new Error('Must connect first');
    }

    const prefixedChannel = `${this.channelPrefix}:${channelName}`;
    
    const subscription = this.cable.subscriptions.create(
      {
        channel: options.channel || 'ApplicationChannel',
        channel_name: prefixedChannel,
        ...options.params
      },
      {
        connected: () => {
          if (options.onConnected) options.onConnected();
        },
        
        disconnected: () => {
          if (options.onDisconnected) options.onDisconnected();
        },
        
        received: (data) => {
          if (options.onMessage) options.onMessage(data);
        },
        
        ...options.callbacks
      }
    );

    this.subscriptions.set(channelName, subscription);
    return subscription;
  }

  // Unsubscribe from channel
  unsubscribe(channelName) {
    const subscription = this.subscriptions.get(channelName);
    if (subscription) {
      subscription.unsubscribe();
      this.subscriptions.delete(channelName);
    }
  }

  // Disconnect all
  disconnect() {
    this.subscriptions.forEach((subscription, channelName) => {
      this.unsubscribe(channelName);
    });
    
    if (this.cable) {
      this.cable.disconnect();
      this.cable = null;
    }
  }

  // Helper for facial sign-on
  subscribeFacialSignOn(token, options = {}) {
    return this.subscribe(`facial_sign_on_login_${token}`, {
      channel: 'FacialSignOnLoginChannel',
      params: { token },
      ...options
    });
  }

  // Check if connected
  isConnected() {
    return this.cable && 
           this.cable.connection && 
           this.cable.connection.webSocket && 
           this.cable.connection.webSocket.readyState === 1;
  }
}

// Usage Example:
/*
// 1. Get site credentials from your backend
// SECURITY FIX: Only public routing info needed - NO Redis credentials!
const siteCredentials = {
  channel_prefix: 'ch_984ab6aee2cd'  // ✅ Public routing info only
  // ❌ redis_username: REMOVED - stays server-side
  // ❌ redis_password: REMOVED - stays server-side  
};

// 2. Initialize client
const axiamClient = new AxiamActionCableClient({
  siteCredentials,
  serverUrl: 'wss://axiam.io/cable'  // Use WSS in production
});

// 3. Connect
await axiamClient.connect();

// 4. Get verification token securely via API (NOT from inline HTML)
const token = await fetchVerificationTokenSecurely();  // CSRF-protected endpoint

// 5. Subscribe to facial sign-on
axiamClient.subscribeFacialSignOn(token, {
  onMessage: (data) => {
    console.log('Facial sign-on update:', data);
    if (data.status === 'success') {
      // Handle successful authentication
      window.location.href = '/dashboard';
    }
  },
  onConnected: () => {
    console.log('Ready to receive facial sign-on updates');
  }
});
*/

// Export for module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = AxiamActionCableClient;
}

// Export to global scope for browser usage with ActionCable dependency check
(function() {
  function exposeAxiamClient() {
    if (typeof ActionCable === 'undefined') {
      setTimeout(exposeAxiamClient, 100);
      return;
    }
    
    if (typeof window !== 'undefined') {
      window.AxiamActionCableClient = AxiamActionCableClient;
      
      // Fire ready event
      if (window.document) {
        const event = new CustomEvent('axiamActionCableReady', { 
          detail: { AxiamActionCableClient } 
        });
        window.document.dispatchEvent(event);
      }
    }
  }
  
  // Start checking for ActionCable
  exposeAxiamClient();
})();
