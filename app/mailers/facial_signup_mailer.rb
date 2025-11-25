class FacialSignupMailer < ApplicationMailer
  default from: ENV.fetch('MAILER_FROM', 'noreply@axiam.io')

  def verification_email(email:, full_name:, verification_url:)
    @full_name = full_name
    @verification_url = verification_url
    
    mail(
      to: email,
      subject: 'Verify your email - Sign in with Face'
    )
  end
end
