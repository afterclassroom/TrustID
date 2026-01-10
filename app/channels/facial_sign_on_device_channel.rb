class FacialSignOnDeviceChannel < ApplicationCable::Channel
  def subscribed
    # 🔒 SECURITY: Check JWT authentication status
    if connection.jwt_payload.blank?
      Rails.logger.warn('[FacialSignOnDeviceChannel] ⚠️ Subscription without JWT authentication (legacy mode)')
      
      # Optional: Enforce JWT requirement
      if ENV['ACTIONCABLE_REQUIRE_JWT'] == 'true'
        Rails.logger.error('[FacialSignOnDeviceChannel] ❌ JWT required but not provided')
        reject
        return
      end
    else
      Rails.logger.info("[FacialSignOnDeviceChannel] ✅ JWT authenticated subscription: site_id=#{connection.jwt_payload['site_id']}")
    end
    
    # Validate client_id parameter
    client_id = params[:client_id]
    
    unless client_id.present?
      Rails.logger.warn "[FacialSignOnDeviceChannel] Reject subscription: missing client_id"
      reject
      return
    end

    # Subscribe to channel for this specific client
    # This matches the broadcast channel used in ClientController#upload_axiam_facial
    channel_name = "facial_sign_on_device_#{client_id}"
    stream_from channel_name
    
    # Send subscription confirmation with JWT status
    transmit({
      type: 'subscription_confirmed',
      site_id: connection.current_site&.id,
      authenticated: connection.current_site.present?,
      jwt_authenticated: connection.jwt_payload.present?,
      client_id: client_id,
      timestamp: Time.current.iso8601
    })

    Rails.logger.info "[FacialSignOnDeviceChannel] Subscribed to #{channel_name} (JWT: #{connection.jwt_payload.present?})"
  end

  def unsubscribed
    Rails.logger.info "[FacialSignOnDeviceChannel] Unsubscribed (connection_id: #{connection.connection_id})"
  end
end
