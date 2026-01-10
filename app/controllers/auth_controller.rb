class AuthController < ApplicationController
  # Skip CSRF verification for API endpoint (if needed)
  # protect_from_forgery except: :axiam_token
  
  # GET /auth/axiam-token
  # Returns JWT token for frontend ActionCable connections
  # Security: This endpoint is server-side only, never exposes API_SECRET
  def axiam_token
    begin
      # Get JWT token from Axiam API (server-to-server)
      token_data = AxiamApi.get_jwt_token
      
      if token_data[:success]
        render json: {
          success: true,
          token: token_data[:token],
          expires_in: token_data[:expires_in],
          expires_at: token_data[:expires_at]
        }
      else
        Rails.logger.error("[Auth] Failed to get JWT token: #{token_data[:error]}")
        render json: {
          success: false,
          error: 'Failed to authenticate with Axiam'
        }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error("[Auth] Exception getting JWT token: #{e.message}")
      render json: {
        success: false,
        error: 'Authentication service unavailable'
      }, status: :service_unavailable
    end
  end
end
