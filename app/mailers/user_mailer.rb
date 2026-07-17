class UserMailer < ApplicationMailer
  default from: User::MAILER_FROM_EMAIL

  def confirmation(user, confirmation_token)
    @user = user
    @confirmation_token = confirmation_token

    mail to: @user.email, subject: "Hajki account confirmation Instructions"
  end

  # locale: "sr" | "en" — follows the language the user had selected in the app.
  def reset_password(user, confirmation_token, locale: "sr")
    @user = user
    @confirmation_token = confirmation_token
    @locale = locale.to_s == "en" ? "en" : "sr"

    subject = @locale == "en" ? "Hajki — password reset" : "Hajki — reset lozinke"
    mail to: @user.email, subject: subject
  end

  def deletion_confirmation(user, token, locale: "sr")
    @user = user
    @token = token
    @locale = locale.to_s == "en" ? "en" : "sr"

    subject = @locale == "en" ? "Confirm Hajki account deletion" : "Potvrda brisanja Hajki naloga"
    mail to: @user.email, subject: subject
  end
end
