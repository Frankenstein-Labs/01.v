# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::CompromisedPasswordDetectionMailer, feature_category: :system_access do
  include EmailSpec::Matchers

  describe '#compromised_password_detection_email' do
    let_it_be(:user) { build_stubbed(:user) }

    subject(:email) { described_class.compromised_password_detection_email(user) }

    it 'is sent to the user' do
      expect(email).to be_delivered_to([user.notification_email_or_default])
    end

    it 'has the correct subject' do
      expect(email).to have_subject('Security Alert: Change Your GitLab.com Password')
    end

    it 'includes instruction to reset your password' do
      expect(email).to have_text_part_content('Please change your password immediately.')
      expect(email).to have_html_part_content('Please change your password immediately.')
    end

    it 'includes the links to relevant docs' do
      expect(email).to have_text_part_content(help_page_url('user/profile/user_passwords.md',
        anchor: 'change-your-password'))
      expect(email).to have_html_part_content(help_page_url('user/profile/user_passwords.md',
        anchor: 'change-your-password'))

      expect(email).to have_text_part_content(help_page_url('user/profile/account/two_factor_authentication.md',
        anchor: 'enable-two-factor-authentication'))
      expect(email).to have_html_part_content(help_page_url('user/profile/account/two_factor_authentication.md',
        anchor: 'enable-two-factor-authentication'))
    end
  end
end
