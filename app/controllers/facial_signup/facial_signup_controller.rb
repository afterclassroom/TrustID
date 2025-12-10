class FacialSignup::FacialSignupController < ApplicationController
  layout 'auth'
  
  skip_before_action :verify_authenticity_token, only: [:create, :complete]
  
  # POST /facial_signup/create - Create client and send verification email
  def create
    email = params[:email]
    full_name = params[:full_name]
    
    if email.blank? || full_name.blank?
      render json: { success: false, error: 'Email and full name are required.' }, status: :unprocessable_entity
      return
    end
    
    begin
      # Call Axiam API to create client with user headers
      # Domain is automatically handled by AxiamApi via ENV['AXIAM_DOMAIN']
      response = AxiamApi.create_client(email: email, full_name: full_name, request_headers: request.headers.to_h)
      
      if response && response['success']
        client_id = response['data']['client_id']
        site_id = response['data']['site_id']
        
        # Store in session for later use
        session[:facial_signup_client_id] = client_id
        session[:facial_signup_site_id] = site_id
        session[:facial_signup_email] = email
        session[:facial_signup_full_name] = full_name
        
        # Generate verification token
        verification_token = SecureRandom.urlsafe_base64(32)
        session[:facial_signup_verification_token] = verification_token
        session[:facial_signup_token_expires_at] = 1.hour.from_now.to_i
        
        # Send verification email
        verification_url = facial_signup_verify_url(token: verification_token, host: request.host_with_port, protocol: request.protocol.chomp('://'))
        
        # Send email (letter_opener in development, SMTP in production/staging)
        begin
          FacialSignupMailer.verification_email(
            email: email,
            full_name: full_name,
            verification_url: verification_url
          ).deliver_now
        rescue Net::OpenTimeout, Net::ReadTimeout => e
          Rails.logger.error "[FacialSignup] SMTP timeout: #{e.message}"
          render json: { success: false, error: "Email service is temporarily unavailable. Please contact support." }, status: :service_unavailable
          return
        rescue => e
          Rails.logger.error "[FacialSignup] Email sending failed: #{e.message}"
          render json: { success: false, error: "Failed to send verification email. Please try again." }, status: :internal_server_error
          return
        end
        
        # Return success response
        render json: { 
          success: true, 
          message: 'Account created! Check your email to verify.',
          pending_url: facial_signup_pending_path
        }
      else
        error_message = response['message'] || 'Failed to create client'
        render json: { success: false, error: error_message }, status: :unprocessable_entity
      end
      
    rescue => e
      Rails.logger.error "[FacialSignup] Error creating client: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, error: "An error occurred: #{e.message}" }, status: :internal_server_error
    end
  end
  
  # GET /facial_signup/pending - Show "check your email" message
  def pending
    # Generate verification URL for display (development/staging)
    if !Rails.env.production? && session[:facial_signup_verification_token].present?
      @verification_url = facial_signup_verify_url(
        token: session[:facial_signup_verification_token], 
        host: request.host_with_port, 
        protocol: request.protocol.chomp('://')
      )
    end
  end
  
  # GET /facial_signup/verify - Verify email and redirect to QR page
  def verify
    token = params[:token]
    
    if token.blank?
      flash[:alert] = 'Invalid verification link.'
      redirect_to new_user_registration_path and return
    end
    
    # Verify token matches session
    if session[:facial_signup_verification_token] != token
      flash[:alert] = 'Invalid or expired verification link. Please start signup again.'
      redirect_to new_user_registration_path and return
    end
    
    # Check token expiration
    expires_at = session[:facial_signup_token_expires_at]
    if expires_at.nil? || Time.now.to_i > expires_at
      flash[:alert] = 'Verification link has expired. Please start signup again.'
      redirect_to new_user_registration_path and return
    end
    
    # Token is valid, clear it and redirect to QR page
    session.delete(:facial_signup_verification_token)
    session.delete(:facial_signup_token_expires_at)
    
    client_id = session[:facial_signup_client_id]
    
    if client_id.blank?
      flash[:alert] = 'Session expired. Please start signup again.'
      redirect_to new_user_registration_path and return
    end
    
    # Redirect to QR page
    redirect_to facial_signup_show_qr_path(client_id: client_id)
  end
  
  # GET /facial_signup/qr/:client_id - Display QR code and handle WebSocket events
  def show_qr
    @client_id = params[:client_id]
    
    # Verify client_id matches session
    unless session[:facial_signup_client_id] == @client_id
      flash[:alert] = 'Invalid session. Please start signup again.'
      redirect_to new_user_registration_path and return
    end
    
    @site_id = session[:facial_signup_site_id]
    @email = session[:facial_signup_email]
    @full_name = session[:facial_signup_full_name]
    
    begin
      # Generate QR code with action=signup and user headers
      # Domain is automatically handled by AxiamApi via ENV['AXIAM_DOMAIN']
      response = AxiamApi.generate_qrcode(client_id: @client_id, action: 'signup', request_headers: request.headers.to_h)
      
      if response && response['success']
        @qrcode = response
      else
        flash[:alert] = response['message'] || 'Failed to generate QR code'
        redirect_to new_user_registration_path
      end
      
    rescue => e
      Rails.logger.error "[FacialSignup] Error generating QR code: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "An error occurred: #{e.message}"
      redirect_to new_user_registration_path
    end
  end
  
  # POST /facial_signup/complete - Complete signup after facial upload
  def complete
    client_id = params[:client_id]
    facial_url = params[:facial_url]
    
    # Get user data from session
    unless session[:facial_signup_client_id] == client_id
      render json: { success: false, message: 'Invalid session' }, status: :unauthorized
      return
    end
    
    email = session[:facial_signup_email]
    full_name = session[:facial_signup_full_name]
    site_id = session[:facial_signup_site_id]
    
    begin
      # Check if user already exists
      user = User.find_by(email: email)
      
      if user
        # Update existing user with axiam_uid and full_name
        user.update!(
          axiam_uid: client_id,
          full_name: full_name
        )
      else
        # Create new user without password (facial-only login)
        user = User.create!(
          email: email,
          axiam_uid: client_id,
          full_name: full_name,
          password: SecureRandom.hex(32)  # Random password (not used for facial login)
        )
      end
      
      # Download and attach facial image from Axiam S3
      if facial_url.present?
        begin
          require 'open-uri'
          
          # Download image from S3
          downloaded_image = URI.open(facial_url)
          
          # Extract filename from URL or use default
          filename = facial_url.split('/').last || "facial_#{client_id}.jpg"
          
          # Attach to user's avatar
          user.avatar.attach(
            io: downloaded_image,
            filename: filename,
            content_type: 'image/jpeg'
          )
          
        rescue => e
          Rails.logger.error "[FacialSignup] Failed to download facial image: #{e.message}"
          # Continue anyway - user is created, just without avatar
        end
      end
      
      # Clear signup session data
      session.delete(:facial_signup_client_id)
      session.delete(:facial_signup_site_id)
      session.delete(:facial_signup_email)
      session.delete(:facial_signup_full_name)
      
      render json: { 
        success: true, 
        message: 'Signup completed successfully',
        redirect_url: new_user_session_path
      }
      
    rescue => e
      Rails.logger.error "[FacialSignup] Error completing signup: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { success: false, message: e.message }, status: :unprocessable_entity
    end
  end
  
  private
  
  # Determine Axiam domain based on environment
  # Must match Site.domain in Axiam database
  def determine_axiam_domain
    # Use environment variable first (recommended for production)
    return ENV['AXIAM_DOMAIN'] if ENV['AXIAM_DOMAIN'].present?
    
    # Fallback to request hostname detection
    hostname = request.host
    
    case hostname
    when 'localhost', '127.0.0.1'
      'localhost'
    when 'veritrustai.net', 'www.veritrustai.net'
      'veritrustai.net'
    when 'webclient.axiam.io'
      'webclient.axiam.io'
    when 'teranet.axiam.io'
      'teranet.axiam.io'
    when 'webclientstaging.axiam.io'
      'webclientstaging.axiam.io'
    else
      # Default to localhost for development
      Rails.logger.warn "[FacialSignup] Unknown hostname: #{hostname}, defaulting to localhost"
      'localhost'
    end
  end
end
