# vi: set fileencoding=utf-8 :

require 'rubygems'
require 'action_mailer'


ActionMailer::Base.smtp_settings = {
  :address => 'smtp.japex.co.jp',
  :port    =>  25,
  :domain  => 'japex.co.jp',
}


class Mailer < ActionMailer::Base
  default :from => 'mailer@ruby.japex.co.jp'

  def a_message(address_to, subject, body)
    mail :to => address_to, :subject => subject, :body => body
  end
end


if __FILE__ == $0
  Mailer.a_message('naoyuki.kumagai@japex.co.jp', 'Test', 'テストです').deliver
end

