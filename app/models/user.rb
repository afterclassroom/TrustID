class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one_attached :avatar
  
  validate :avatar_type_and_size

  private

  def avatar_type_and_size
    return unless avatar.attached?

    # Allow any image content type (image/*)
    unless avatar.blob.content_type&.start_with?('image/')
      errors.add(:avatar, 'must be an image')
    end

    size = avatar.blob.byte_size
    min_size = 100.kilobytes
    max_size = 10.megabytes

    if size < min_size
      errors.add(:avatar, "is too small (minimum is #{min_size / 1.kilobyte} KB)")
    elsif size > max_size
      errors.add(:avatar, "is too big (maximum is #{max_size / 1.megabyte} MB)")
    end
  end
end
