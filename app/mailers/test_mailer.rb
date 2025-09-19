class TestMailer < ApplicationMailer
  def hello_email
    mail(to: "tamarabolmanac@gmail.com", subject: "Test iz Brevo SMTP-a") do |format|
      format.text { render plain: "Pozdrav, ovo je test mejl iz Rails aplikacije preko Brevo SMTP-a" }
    end
  end
end
