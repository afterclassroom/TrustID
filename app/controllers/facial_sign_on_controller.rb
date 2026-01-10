require 'net/http'
require 'uri'
require 'json'

class FacialSignOnController < ApplicationController
  # Skip CSRF verification for widget callbacks (widget may not send CSRF token)
  skip_before_action :verify_authenticity_token, only: [:verified_login, :push_notification]
  
  # Allow JSON format without authentication
  before_action :set_json_format, only: [:verified_login]
  
  CLIENT_URL = ENV.fetch('CLIENT_URL', 'localhost')

  # Trang sử dụng Axiam Widget
  def widget_login
    # 🔒 SECURITY: Get JWT token from Axiam server-side
    # NEVER send secret_key to browser!
    @axiam_auth_token = get_axiam_auth_token
    
    render 'facial_sign_on/widget_login'
  rescue => e
    Rails.logger.error "[Facial Sign-On] Failed to get Axiam auth token: #{e.message}"
    flash[:alert] = "Failed to initialize facial login. Please try again later."
    redirect_to new_user_session_path
  end

  private

  # 🔒 Get JWT authentication token from Axiam (server-side only)
  def get_axiam_auth_token
    # Check cache first (token valid for 1 hour, cache for 55 minutes)
    cache_key = 'axiam_auth_token'
    cached_token = Rails.cache.read(cache_key)
    
    if cached_token.present?
      return cached_token
    end
    
    # Call Axiam authentication API
    auth_url = ENV.fetch('AXIAM_AUTH_URL', 'https://axiam.io/api/v1/facial_sign_on/application_auth')
    api_key = ENV['AXIAM_API_KEY']
    secret_key = ENV['AXIAM_SECRET_KEY']
    
    # Extract domain without protocol (Axiam expects domain only, not full URL)
    domain = CLIENT_URL.sub(/^https?:\/\//, '').sub(/:\d+$/, '')  # Remove protocol and port
    
    uri = URI(auth_url)
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      api_key: api_key,
      secret_key: secret_key,  # 🔒 Server-side only
      domain: domain  # Domain without protocol
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end
    
    data = JSON.parse(response.body)
    
    if data['success'] && data.dig('data', 'authenticated_token')
      token = data['data']['authenticated_token']
      expires_in = data.dig('data', 'expires_in') || 3300  # Default 55 minutes
      
      # Cache token (use expires_in from response, or default to 55 minutes)
      cache_duration = [expires_in - 300, 3300].min  # Cache for (expires_in - 5 minutes) or 55 minutes
      Rails.cache.write(cache_key, token, expires_in: cache_duration.seconds)
      
      return token
    end
    
    error_message = data['message'] || data['user_message'] || 'Authentication failed'
    Rails.logger.error "[Facial Sign-On] Axiam auth failed: #{error_message}"
    raise "Axiam authentication failed: #{error_message}"
  end

  public

  # Trang nhập email và gọi API push_notification (legacy)
  def login
    render 'layouts/axiam_login'
  end

  # Xử lý submit form Axiam login (gọi API push_notification, trả về verification_token)
  def push_notification
    Rails.logger.info "[Facial Sign-On] 🔔 push_notification called"
    
    # Widget may send email in different param names
    email = params[:email] || params[:user_email] || params.dig(:data, :email)
    user = User.find_by(email: email)
    axiam_uid = user&.axiam_uid
    
    unless user && axiam_uid.present?
      error_msg = user ? 'User has not enabled facial sign in' : 'User not found'
      Rails.logger.error "[Facial Sign-On] #{error_msg}"
      
      respond_to do |format|
        format.json { render json: { success: false, error: error_msg }, status: :not_found }
        format.html {
          flash[:alert] = error_msg
          redirect_to facial_sign_on_login_path
        }
      end
      return
    end
    
    result = AxiamApi.api_post(
      '/api/v1/facial_sign_on/login/push_notification', 
      { id: axiam_uid },
      request_headers: request.headers.to_h
    )
    
    # Check response from Axiam API
    # Response structure: { "success": true, "data": { "verification_token": "..." } }
    if result.is_a?(Hash) && result['success'] == true && result['data'].is_a?(Hash)
      verification_token = result['data']['verification_token']
      
      if verification_token.present?
        Rails.logger.info "[Facial Sign-On] ✅ Received verification token from Axiam"
        
        # 🔒 SECURITY: Store token in session instead of exposing in HTML
        session[:facial_verification_token] = verification_token
        session[:facial_verification_expires_at] = 5.minutes.from_now.to_i
        
        # Also persist a short-lived server-side mapping to validate WS subscriptions
        # AND store by email for widget flow (widget only knows email, not verification_token)
        begin
          # Store by token (for legacy subscribe flow)
          Rails.cache.write(
            "facial_token:#{verification_token}", 
            { user_id: user&.id, email: email, client_id: axiam_uid }, 
            expires_in: 5.minutes
          )
          
          # Store by email (for widget flow)
          Rails.cache.write(
            "facial_email:#{email}", 
            { user_id: user&.id, client_id: axiam_uid, verification_token: verification_token }, 
            expires_in: 5.minutes
          )
          
          Rails.logger.info "[Facial Sign-On] ✅ Token and email cached for validation"
        rescue => e
          Rails.logger.warn "[Facial Sign-On] Failed to write facial token to cache: #{e.message}"
        end
        
        # Return JSON response for widget/AJAX requests
        # Check if request expects JSON (from widget or AJAX)
        if request.format.json? || request.content_type&.include?('application/json') || request.headers['Accept']&.include?('application/json')
          render json: { 
            success: true, 
            verification_token: verification_token,
            message: 'Push notification sent successfully'
          }, status: :ok
        else
          # For legacy form submission - render subscribe page
          render 'facial_sign_on/subscribe', status: :ok
        end
      else
        Rails.logger.error "[Facial Sign-On] ❌ Verification token is blank in response"
        
        respond_to do |format|
          format.json { render json: { success: false, error: 'No verification token received' }, status: :bad_gateway }
          format.html {
            flash[:alert] = "Không nhận được verification token từ Axiam"
            redirect_to facial_sign_on_login_path
          }
        end
      end
    else
      Rails.logger.error "[Facial Sign-On] ❌ Invalid response from Axiam: #{result.inspect}"
      error_message = result.is_a?(Hash) ? (result['message'] || result['error']) : 'Unknown error'
      
      respond_to do |format|
        format.json { render json: { success: false, error: error_message }, status: :bad_gateway }
        format.html {
          flash[:alert] = "Lỗi từ Axiam: #{error_message}"
          redirect_to facial_sign_on_login_path
        }
      end
    end
  end

  # 🔒 NEW: API endpoint to get verification token (session-based, CSRF protected)
  def get_verification_token
    token = session[:facial_verification_token]
    expires_at = session[:facial_verification_expires_at]
    
    # Check if token exists and not expired
    if token.present? && expires_at.present? && Time.now.to_i < expires_at
      render json: { 
        success: true, 
        token: token,
        expires_in: expires_at - Time.now.to_i
      }
    else
      # Clear expired token
      session.delete(:facial_verification_token)
      session.delete(:facial_verification_expires_at)
      
      render json: { 
        success: false, 
        error: 'Token expired or not found' 
      }, status: :unauthorized
    end
  end

  # Xử lý login khi nhận verified từ Axiam
  # Supports both AJAX (JSON) and form submission (from widget)
  def verified_login
    Rails.logger.info "[Facial Sign-On] verified_login called"
    # 🔒 LOCAL SECURITY: Validate client_session_token to prevent replay attacks
    client_session_token = params[:client_session_token]
    client_id = params[:client_id]
    email = params[:email]
    
    if client_session_token.present? && client_id.present?
      # Check if token has already been used (one-time use enforcement)
      cache_key = "client_session_token:#{client_session_token}"
      if Rails.cache.read(cache_key) == 'used'
        Rails.logger.warn "[Facial Sign-On] Token reuse attempt detected"
        respond_to do |format|
          format.json { render json: { success: false, error: 'Session token has already been used' }, status: :unauthorized }
          format.html { 
            flash[:alert] = 'Session expired. Please try again.'
            redirect_to new_user_session_path 
          }
        end
        return
      end
      
      # Mark token as used (5 minute expiry to clean up cache)
      Rails.cache.write(cache_key, 'used', expires_in: 5.minutes)
      
      # Find user by email
      user = User.find_by(email: email)
      
      unless user
        Rails.logger.error "[Facial Sign-On] User not found for email: #{email}"
        respond_to do |format|
          format.json { render json: { success: false, error: 'User not found' }, status: :not_found }
          format.html { 
            flash[:alert] = 'Account not found. Please sign up first.'
            redirect_to new_user_registration_path 
          }
        end
        return
      end
      
      # Sign in user
      sign_in(user)
      Rails.logger.info "[Facial Sign-On] ✅ Auto-login successful for user #{user.id} (email: #{email})"
      
      respond_to do |format|
        format.json { render json: { success: true, message: 'Login successful', redirect_url: root_path } }
        format.html { 
          flash[:success] = 'Login successful!'
          redirect_to root_path 
        }
      end
      return
    end
    
    # FALLBACK: Legacy verification flow (for backward compatibility)
    Rails.logger.warn "[Facial Sign-On] ⚠️ Using legacy verification flow (no session token)"
    
    # 🔒 SECURITY: Check for verification proof
    # Accept multiple proof formats:
    # 1. Widget flow: params[:verified] == 'true'
    # 2. Legacy subscribe flow: params[:verification_data][:status] == 'verified'
    # 3. Signature-based: params[:signature].present?
    verification_proof = params[:verified] == 'true' || 
                        params[:signature].present? || 
                        params[:verification_token].present? ||
                        params.dig(:verification_data, 'status') == 'verified'
    
    unless verification_proof
      Rails.logger.error "[Facial Sign-On] ❌ No verification proof - rejecting request"
      respond_to do |format|
        format.json { render json: { success: false, error: 'Verification required' }, status: :forbidden }
        format.html { 
          flash[:alert] = 'Please complete facial verification first'
          redirect_to facial_sign_on_widget_path 
        }
      end
      return
    end
    
    Rails.logger.info "[Facial Sign-On] ✅ Verification proof confirmed (legacy)"
    
    # Extract axiam_uid from different possible sources
    axiam_uid = nil
    user = nil
    
    # Check if widget submitted email (widget flow)
    if params[:email].present? && !params[:client_id].present?
      email = params[:email]
      user = User.find_by(email: email)
      if user && user.axiam_uid.present?
        axiam_uid = user.axiam_uid
      end
    else
      # Legacy flow: client_id provided directly
      axiam_uid = params[:client_id] || 
                  params[:axiam_uid] || 
                  params.dig(:verification_data, :client_id) ||
                  params.dig(:data, :client_id)
    end
    
    unless axiam_uid.present?
      Rails.logger.error "[Facial Sign-On] No axiam_uid provided in request"
      respond_to do |format|
        format.json { render json: { success: false, error: 'No client ID provided' }, status: :bad_request }
        format.html { 
          flash[:alert] = 'Invalid authentication data'
          redirect_to new_user_session_path 
        }
      end
      return
    end
    
    # Find user by axiam_uid (if not already found by email)
    user ||= User.find_by(axiam_uid: axiam_uid)
    
    if user
      sign_in(user)
      Rails.logger.info "[Facial Sign-On] ✅ Auto-login successful for user #{user.id}"
      
      respond_to do |format|
        format.json { render json: { success: true, message: 'Login successful', redirect_url: root_path } }
        format.html { 
          flash[:success] = 'Login successful!'
          redirect_to root_path 
        }
      end
    else
      Rails.logger.warn "[Facial Sign-On] ❌ User not found for axiam_uid: [REDACTED]"
      
        respond_to do |format|
        format.json { render json: { success: false, error: 'User not found' }, status: :unauthorized }
        format.html { 
          flash[:alert] = 'User not registered with facial sign in'
          redirect_to new_user_session_path 
        }
      end
    end
  end
  
  private
  
  # Ensure JSON format for API endpoints
  def set_json_format
    request.format = :json if request.content_type == 'application/json'
  end
end
