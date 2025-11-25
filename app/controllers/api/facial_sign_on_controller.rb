# frozen_string_literal: true

module Api
  class FacialSignOnController < ApplicationController
    # Skip CSRF for API endpoints (frontend will send X-CSRF-Token header)
    skip_before_action :verify_authenticity_token, only: [:lookup, :push_notification]
    
    # Step 2: Lookup client by email
    # POST /api/facial_sign_on/lookup
    def lookup
      email = params[:email]
      
      if email.blank?
        return render json: {
          success: false,
          message: 'Email is required',
          user_message: 'Please enter your email address',
          code: 1006
        }, status: :bad_request
      end
      
      # Validate email format
      unless email.match?(URI::MailTo::EMAIL_REGEXP)
        return render json: {
          success: false,
          message: 'Invalid email format',
          user_message: 'Please enter a valid email address',
          code: 1006
        }, status: :bad_request
      end
      
      begin
        # Call Axiam API
        response = AxiamApi.lookup_client(email: email)
        
        # Return response from Axiam
        if response['success']
          render json: response, status: :ok
        else
          # Map Axiam error codes to appropriate HTTP status
          http_status = case response['code']
          when 1007 # Client not found
            :not_found
          when 1002 # Facial not enabled
            :forbidden
          when 1013 # Account locked
            :forbidden
          else
            :bad_request
          end
          
          render json: response, status: http_status
        end
        
      rescue StandardError => e
        Rails.logger.error "[FacialSignOn] Lookup error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        render json: {
          success: false,
          message: 'Server error',
          user_message: 'An error occurred. Please try again.',
          code: 5000
        }, status: :internal_server_error
      end
    end
    
    # Step 3: Push notification to mobile app
    # POST /api/facial_sign_on/push_notification
    def push_notification
      client_id = params[:client_id]
      
      if client_id.blank?
        return render json: {
          success: false,
          message: 'Client ID is required',
          user_message: 'Invalid request',
          code: 1025
        }, status: :bad_request
      end
      
      begin
        # Call Axiam API
        response = AxiamApi.push_notification(client_id: client_id)
        
        # Return response from Axiam
        if response['success']
          render json: response, status: :ok
        else
          # Map error codes
          http_status = case response['code']
          when 1012 # Device not registered
            :not_found
          when 1013 # Account locked
            :forbidden
          when 1020, 1021 # Rate limit
            :too_many_requests
          else
            :bad_request
          end
          
          render json: response, status: http_status
        end
        
      rescue StandardError => e
        Rails.logger.error "[FacialSignOn] Push notification error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        render json: {
          success: false,
          message: 'Server error',
          user_message: 'Failed to send notification. Please try again.',
          code: 5000
        }, status: :internal_server_error
      end
    end
  end
end
