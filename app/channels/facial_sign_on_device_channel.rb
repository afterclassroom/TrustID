class FacialSignOnDeviceChannel < ApplicationCable::Channel
  def subscribed
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

    Rails.logger.info "[FacialSignOnDeviceChannel] Subscribed to #{channel_name}"
  end

  def unsubscribed
    Rails.logger.info "[FacialSignOnDeviceChannel] Unsubscribed"
  end
end
