# frozen_string_literal: true

module Api
  class SessionsController < ApplicationController
    # Skip CSRF for API endpoint
    skip_before_action :verify_authenticity_token, only: [:create]
    
    # POST /api/sessions
    # Create session after facial login verified via ActionCable
    def create
      client_id = params[:client_id]
      email = params[:email]
      login_method = params[:login_method]
      
      # Validate required params
      if client_id.blank? || email.blank?
        return render json: {
          success: false,
          message: 'Missing required parameters',
          user_message: 'Invalid login request'
        }, status: :bad_request
      end
      
      # Validate login method
      unless login_method == 'facial_sign_on'
        return render json: {
          success: false,
          message: 'Invalid login method',
          user_message: 'Invalid login method'
        }, status: :bad_request
      end
      
      begin
        # Find user by email
        user = User.find_by(email: email)
        
        unless user
          return render json: {
            success: false,
            message: 'User not found',
            user_message: 'No account found with this email address.'
          }, status: :not_found
        end
        
        # Verify client_id matches user's Axiam UID
        if user.axiam_uid.present? && user.axiam_uid != client_id
          Rails.logger.error "[SessionsController] Client ID mismatch. User: #{user.axiam_uid}, Provided: #{client_id}"
          return render json: {
            success: false,
            message: 'Client ID mismatch',
            user_message: 'Invalid login credentials'
          }, status: :forbidden
        end
        
        # Update axiam_uid if not set
        if user.axiam_uid.blank?
          user.update!(axiam_uid: client_id)
        end
        
        # Sign in user using Devise
        sign_in(:user, user)
        
        render json: {
          success: true,
          message: 'Session created',
          user: {
            id: user.id,
            email: user.email,
            client_id: client_id
          }
        }, status: :ok
        
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[SessionsController] User creation failed: #{e.message}"
        
        render json: {
          success: false,
          message: 'User creation failed',
          user_message: 'Failed to create account. Please contact support.'
        }, status: :unprocessable_entity
        
      rescue StandardError => e
        Rails.logger.error "[SessionsController] Session creation error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        render json: {
          success: false,
          message: 'Server error',
          user_message: 'Login failed. Please try again.'
        }, status: :internal_server_error
      end
    end
    
    # GET /api/sessions/current
    # Check current session
    def current
      if current_user
        render json: {
          success: true,
          user: {
            id: current_user.id,
            email: current_user.email
          }
        }, status: :ok
      else
        render json: {
          success: false,
          message: 'Not authenticated'
        }, status: :unauthorized
      end
    end
    
    # DELETE /api/sessions
    # Logout
    def destroy
      sign_out(current_user) if current_user
      
      render json: {
        success: true,
        message: 'Logged out successfully'
      }, status: :ok
    end
  end
end
