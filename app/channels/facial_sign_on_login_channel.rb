class FacialSignOnLoginChannel < ApplicationCable::Channel
  def subscribed
    # Get verification_token from params
    token = params[:token]
    
    if token.blank?
      Rails.logger.warn "[FacialSignOnLoginChannel] Reject subscription: missing token"
      reject
      return
    end
    
    # Subscribe to channel: facial_sign_on_login_{verification_token}
    # Axiam server will broadcast to this channel when mobile app verifies login
    channel_name = "facial_sign_on_login_#{token}"
    stream_from channel_name
    
    Rails.logger.info "[FacialSignOnLoginChannel] Subscribed to: #{channel_name}"
  end

  def unsubscribed
    Rails.logger.info "[FacialSignOnLoginChannel] Unsubscribed"
  end
end
