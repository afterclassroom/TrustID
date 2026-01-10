class FacialSignOnLoginChannel < ApplicationCable::Channel
  def subscribed
    # 🔒 SECURITY: Check JWT authentication status
    if connection.jwt_payload.blank?
      Rails.logger.warn('[FacialSignOnLoginChannel] ⚠️ Subscription without JWT authentication (legacy mode)')
      
      # Optional: Enforce JWT requirement (set ACTIONCABLE_REQUIRE_JWT=true)
      if ENV['ACTIONCABLE_REQUIRE_JWT'] == 'true'
        Rails.logger.error('[FacialSignOnLoginChannel] ❌ JWT required but not provided')
        reject
        return
      end
    else
      Rails.logger.info("[FacialSignOnLoginChannel] ✅ JWT authenticated subscription: site_id=#{connection.jwt_payload['site_id']}")
    end
    
    # Get verification_token from params (supports both 'token' and 'verification_token')
    verification_token = params[:verification_token] || params[:token]
    
    if verification_token.blank?
      Rails.logger.warn "[FacialSignOnLoginChannel] Reject subscription: missing verification_token"
      reject
      return
    end
    
    # 🔒 SECURITY: Cross-check JWT and verification token (if both present)
    if connection.jwt_payload.present?
      # Get cached token data to validate site_id match
      cached_token_data = Rails.cache.read("facial_verification_token:#{verification_token}")
      
      if cached_token_data.present?
        jwt_site_id = connection.jwt_payload['site_id']
        token_site_id = cached_token_data[:site_id]
        
        # Validate site_id match (skip if token_site_id is 0 - global token)
        if token_site_id.to_i != 0 && token_site_id.to_s != jwt_site_id.to_s
          Rails.logger.error("[FacialSignOnLoginChannel] ❌ Site mismatch: JWT site_id=#{jwt_site_id}, Token site_id=#{token_site_id}")
          reject
          return
        end
      else
        Rails.logger.warn("[FacialSignOnLoginChannel] ⚠️ Verification token not found in cache: #{verification_token}")
        # Don't reject - token might be from Axiam side
      end
    end
    
    # Subscribe to channel: facial_sign_on_login_{verification_token}
    # Axiam server will broadcast to this channel when mobile app verifies login
    channel_name = "facial_sign_on_login_#{verification_token}"
    stream_from channel_name
    
    # Send subscription confirmation with JWT status
    transmit({
      type: 'subscription_confirmed',
      site_id: connection.current_site&.id,
      authenticated: connection.current_site.present?,
      jwt_authenticated: connection.jwt_payload.present?,
      verification_token: verification_token,
      timestamp: Time.current.iso8601
    })
    
    Rails.logger.info "[FacialSignOnLoginChannel] Subscribed to: #{channel_name} (JWT: #{connection.jwt_payload.present?})"
  end

  def unsubscribed
    Rails.logger.info "[FacialSignOnLoginChannel] Unsubscribed (connection_id: #{connection.connection_id})"
  end
end
