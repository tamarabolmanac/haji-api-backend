class UserMailer < ApplicationMailer
  default from: User::MAILER_FROM_EMAIL

  def confirmation(user, confirmation_token)
    @user = user
    @confirmation_token = confirmation_token

    mail to: @user.email, subject: "Hajki account confirmation Instructions"
  end

  def reset_password(user, confirmation_token)
    @user = user
    @confirmation_token = confirmation_token

    mail to: @user.email, subject: "Reset Password Instructions"
  end

  def deletion_confirmation(user, token)
    @user = user
    @token = token

    mail to: @user.email, subject: "Potvrda brisanja Hajki naloga"
  end
end