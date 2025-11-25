module ApplicationHelper
  # ⚠️ SECURITY WARNING: This method contains SENSITIVE DATA (Redis credentials)
  # 
  # Usage: SERVER-SIDE ONLY (controller/channel/background jobs)
  # 
  # Purpose: Full credentials for server-to-server communication with Axiam
  # 
  # ❌ NEVER expose to client-side JavaScript
  # ❌ NEVER send in API responses to browser
  # ❌ NEVER include in views/templates
  # 
  # ✅ Use axiam_credentials_js() for client-side instead
  #
  # Last Updated: November 2025 (Axiam v2.0 Security Review)
  def axiam_credentials_full
    {
      redis_username: Rails.application.credentials.redis_username || ENV['REDIS_USERNAME'],
      redis_password: Rails.application.credentials.redis_password || ENV['REDIS_PASSWORD'], 
      channel_prefix: Rails.application.credentials.channel_prefix || ENV['CHANNEL_PREFIX'],
      server_url: axiam_server_url
    }
  end
  
  # ✅ SECURITY: This method is SAFE for client-side exposure
  # 
  # Usage: CLIENT-SIDE JavaScript (views, templates, API responses)
  # 
  # Purpose: Public routing information for ActionCable connection
  # 
  # Contains ONLY:
  # - channel_prefix: Public routing identifier (multi-tenant channel selection)
  # - server_url: WebSocket endpoint URL (environment-specific)
  # 
  # Does NOT contain:
  # - Redis username/password (server-side only)
  # - API keys/secrets (server-side only)
  # - Any sensitive credentials
  # 
  # Used in: application.html.erb → window.SITE_CREDENTIALS
  #
  # Last Updated: November 2025 (Axiam v2.0 Migration)
  def axiam_credentials_js
    {
      channel_prefix: Rails.application.credentials.channel_prefix || ENV['CHANNEL_PREFIX'],
      server_url: axiam_server_url
    }
  end
  
  # Validate full credentials (server-side only)
  def axiam_credentials_valid?
    credentials = axiam_credentials_full
    if credentials.values.any?(&:blank?)
      Rails.logger.error "[Axiam] Missing credentials: some required credentials are not set"
      return false
    end
    true
  end
  
  # Environment-aware ActionCable server URL
  # Returns appropriate WebSocket URL based on Rails environment
  #
  # Development: ws://localhost:3000/cable (local Axiam container)
  # Staging:     wss://staging.axiam.io/cable (staging environment)
  # Production:  wss://axiam.io/cable (production environment)
  #
  # Note: Uses secure WebSocket (wss://) in staging/production
  def axiam_server_url
    # Environment-based URL selection
    # Can be overridden by AXIAM_SERVER_URL environment variable
    return ENV['AXIAM_SERVER_URL'] if ENV['AXIAM_SERVER_URL'].present?
    
    case Rails.env
    when 'development'
      "ws://localhost:3000/cable"
    when 'staging'
      "wss://staging.axiam.io/cable"
    when 'production'
      # TODO: Update this URL to match actual Axiam production server
      "wss://axiam.io/cable"
    else
      "ws://localhost:3000/cable"
    end
  end
end
