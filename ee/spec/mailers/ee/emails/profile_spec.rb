# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

RSpec.describe EE::Emails::Profile do
  include EmailSpec::Matchers

  let_it_be(:user) { create(:user) }

  describe '#policy_revoked_personal_access_tokens_email' do
    let(:token_names) { %w[name1 name2] }

    subject { Notify.policy_revoked_personal_access_tokens_email(user, token_names) }

    it 'is sent to the user' do
      is_expected.to deliver_to user.email
    end

    it 'has the correct subject' do
      is_expected.to have_subject(/^One or more of you personal access tokens were revoked$/i)
    end

    it 'mentions the access tokens were revoke' do
      is_expected.to have_body_text(/The following personal access tokens: name1 and name2 were revoked/)
    end

    it 'includes a link to personal access tokens page' do
      is_expected.to have_body_text(/#{user_settings_personal_access_tokens_path}/)
    end

    it 'includes the email reason' do
      is_expected.to have_body_text %r{You're receiving this email because of your account on <a .*>localhost<\/a>}
    end
  end

  describe '#pipl_compliance_notification' do
    subject { Notify.pipl_compliance_notification(user, pipl_user.pipl_access_end_date) }

    let_it_be(:pipl_user) do
      create(:pipl_user, initial_email_sent_at: Time.current, user: user)
    end

    it 'has the correct subject' do
      is_expected.to have_subject('Important Change to Your GitLab.com Account')
    end

    it 'includes the link to jihu' do
      is_expected.to have_body_text('https://gitlab.cn/saasmigration/')
    end

    it 'includes the contact email' do
      is_expected.to have_body_text('saasmigration@gitlab.cn')
    end

    it 'includes the correctly formatted date' do
      is_expected.to have_body_text(pipl_user.pipl_access_end_date.strftime('%B %d, %Y').to_s)
    end
  end
end
