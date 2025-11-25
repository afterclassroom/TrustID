class Users::RegistrationsController < Devise::RegistrationsController
  layout 'auth', only: [:new]
  before_action :configure_permitted_parameters

  CLIENT_URL = ENV.fetch('CLIENT_URL', 'localhost')

  # Show facial signup form
  def new
    super
  end

  # Khi user đăng ký thành công, gọi API tạo client bên Axiam
  def create
    super do |resource|
      if resource.persisted?
        result = AxiamApi.api_post('/api/v1/facial_sign_on/client/create', { email: resource.email, full_name: resource.full_name }, domain: CLIENT_URL)
        if result && result['data'] && result['data']['client_id']
          resource.update(axiam_uid: result['data']['client_id'])
        end
      end
    end
  end

  # Khi user cập nhật avatar, gọi API upload_facial nếu có file avatar
  def update
    avatar_uploaded = params[:user] && params[:user][:avatar].present?

    Rails.logger.info "[RegistrationsController] update called. return_to_present=#{params[:return_to].present?}, avatar_uploaded=#{avatar_uploaded}"

    super do |resource|
      next unless resource.persisted? && avatar_uploaded

      resource.reload # ensure attachment is persisted

      unless resource.avatar.attached?
        flash_message = 'Avatar is not attached'
        if params[:return_to].present?
          flash[:alert] = flash_message
          redirect_to params[:return_to] and return
        else
          flash.now[:alert] = flash_message
          render :edit and return
        end
      end

      # Perform the multipart upload and handle response
      begin
        upload_result = AxiamApi.upload_facial('/api/v1/facial_sign_on/client/upload_facial', resource.axiam_uid, resource.avatar, domain: CLIENT_URL)
      rescue => e
        # Log a generic error and write full exception to debug for ops
        Rails.logger.error "[RegistrationsController] Axiam upload error (see debug logs)"
        Rails.logger.debug { "[RegistrationsController] Axiam upload exception: #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}" }
        Rails.logger.info "[RegistrationsController] handling upload exception; return_to_present=#{params[:return_to].present?}"
        # Remove the attached avatar locally because remote upload failed
        begin
          resource.avatar.purge if resource.avatar.attached?
        rescue => purge_err
          Rails.logger.error "[RegistrationsController] Failed to purge avatar after upload error: #{purge_err.message}"
        end

        flash_message = "Axiam upload error. Please try again later."
        if params[:return_to].present?
          Rails.logger.info "[RegistrationsController] redirecting to return_to (present) after upload exception"
          flash[:alert] = flash_message
          redirect_to params[:return_to] and return
        else
          Rails.logger.info "[RegistrationsController] rendering :edit after upload exception"
          flash.now[:alert] = flash_message
          render :edit and return
        end
      end

      if upload_result.nil? || (upload_result['success'] != true && upload_result['data'].blank?)
        user_message = upload_result && upload_result['user_message'] ? upload_result['user_message'] : 'Axiam upload failed.'
        # Purge local avatar because remote validation failed
        begin
          resource.avatar.purge if resource.avatar.attached?
        rescue => purge_err
          Rails.logger.error "[RegistrationsController] Failed to purge avatar after remote validation failure: #{purge_err.message}"
        end

        if params[:return_to].present?
          Rails.logger.info "[RegistrationsController] redirecting to return_to (present) after upload_result failure"
          # user_message may come from remote API and could contain sensitive detail; present a safe message
          safe_message = user_message.present? ? user_message : 'Axiam upload failed.'
          flash[:alert] = safe_message
          redirect_to params[:return_to] and return
        else
          Rails.logger.info "[RegistrationsController] rendering :edit after upload_result failure"
          safe_message = user_message.present? ? user_message : 'Axiam upload failed.'
          flash.now[:alert] = safe_message
          render :edit and return
        end
      end
      # success: continue normally (Devise will redirect)
    end
  end

  # Bật tính năng đăng nhập khuôn mặt (hiển thị QRCode và upload avatar)
  def enable_facial_sign_on
    # Gọi API lấy QRCode bằng POST, truyền id là axiam_uid
    @qrcode = AxiamApi.api_post('/api/v1/facial_sign_on/client/qrcode', { id: current_user.axiam_uid }, domain: CLIENT_URL)
    render 'devise/registrations/enable_facial_sign_on'
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:full_name, :avatar])
    devise_parameter_sanitizer.permit(:account_update, keys: [:full_name, :avatar])
  end

  def update_resource(resource, params)
    resource.update_without_password(params)
  end
end
