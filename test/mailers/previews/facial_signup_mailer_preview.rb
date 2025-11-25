# Preview all emails at http://localhost:3030/rails/mailers/facial_signup_mailer
class FacialSignupMailerPreview < ActionMailer::Preview
  def verification_email
    FacialSignupMailer.verification_email(
      email: 'user@example.com',
      full_name: 'John Doe',
      verification_url: 'http://localhost:3030/facial_signup/verify?token=sample_verification_token_here'
    )
  end
end
