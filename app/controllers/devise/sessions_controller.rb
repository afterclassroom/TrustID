# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

class Devise::SessionsController < DeviseController
  layout 'auth'
  
  prepend_before_action :require_no_authentication, only: [:new, :create]
  prepend_before_action :allow_params_authentication!, only: :create
  prepend_before_action only: [:create, :destroy] do
    request.env["devise.skip_timeout"] = true
  end

  # GET /resource/sign_in
  def new
    # 🔒 SECURITY: Get JWT token from Axiam server-side for widget
    @axiam_auth_token = get_axiam_auth_token
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    yield resource if block_given?
    respond_with(resource, serialize_options(resource))
  rescue => e
    Rails.logger.error "[Devise Sessions] Failed to get Axiam auth token: #{e.message}"
    @axiam_auth_token = nil
    self.resource = resource_class.new(sign_in_params)
    clean_up_passwords(resource)
    yield resource if block_given?
    respond_with(resource, serialize_options(resource))
  end

  # POST /resource/sign_in
  def create
    self.resource = warden.authenticate!(auth_options)
    set_flash_message!(:notice, :signed_in)
    sign_in(resource_name, resource)
    yield resource if block_given?
    respond_with resource, location: after_sign_in_path_for(resource)
  end

  # DELETE /resource/sign_out
  def destroy
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message! :notice, :signed_out if signed_out
    yield if block_given?
    respond_to_on_destroy
  end

  protected

  def sign_in_params
    devise_parameter_sanitizer.sanitize(:sign_in)
  end

  def serialize_options(resource)
    methods = resource_class.authentication_keys.dup
    methods = methods.keys if methods.is_a?(Hash)
    methods << :password if resource.respond_to?(:password)
    { methods: methods, only: [:password] }
  end

  def auth_options
    { scope: resource_name, recall: "#{controller_path}#new" }
  end

  def translation_scope
    'devise.sessions'
  end

  private

  # 🔒 Get JWT authentication token from Axiam (server-side only)
  def get_axiam_auth_token
    # Check cache first (token valid for 30 days, cache for 30 days - 5 minutes)
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
    client_url = ENV.fetch('CLIENT_URL', 'localhost')
    domain = client_url.sub(/^https?:\/\//, '').sub(/:\d+$/, '')  # Remove protocol and port
    
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
      expires_in = data.dig('data', 'expires_in') || 2592000  # Default 30 days
      
      # Cache token (use expires_in from response, or default to 30 days - 5 minutes)
      cache_duration = [expires_in - 300, 2591700].min  # Cache for (expires_in - 5 minutes)
      Rails.cache.write(cache_key, token, expires_in: cache_duration.seconds)
      
      Rails.logger.info "[Devise Sessions] ✅ Axiam auth token obtained and cached for #{cache_duration} seconds"
      return token
    end
    
    error_message = data['message'] || data['user_message'] || 'Authentication failed'
    Rails.logger.error "[Devise Sessions] Axiam auth failed: #{error_message}"
    raise "Axiam authentication failed: #{error_message}"
  end

  def respond_to_on_destroy
    # We actually need to hardcode this as Rails default responder doesn't
    # support returning empty response on GET request
    respond_to do |format|
      format.all { head :no_content }
      format.any(*navigational_formats) { redirect_to after_sign_out_path_for(resource_name), status: Devise.responder.redirect_status }
    end
  end
end
