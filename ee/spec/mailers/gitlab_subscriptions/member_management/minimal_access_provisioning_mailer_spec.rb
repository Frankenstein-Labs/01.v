# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::MinimalAccessProvisioningMailer, feature_category: :seat_cost_management do
  include EmailSpec::Matchers

  let(:user) { build(:user) }
  let(:user_count) { 10 }
  let(:sync_date) { Date.yesterday.iso8601 }

  let(:email_subject) do
    s_('MinimalAccessProvisioning|Action required: Users assigned Minimal Access role due to seat constraints')
  end

  let(:expected_body_text) do
    s_(
      'MinimalAccessProvisioning|We\'re notifying you that 10 users provisioned through ' \
        'LDAP or SAML/SCIM have been assigned the Minimal Access role'
    )
  end

  describe '#notify_group_owner' do
    let(:namespace) { build(:group) }

    subject(:email) do
      described_class.notify_group_owner(
        namespace: namespace, recipient: user, user_count: user_count, sync_date: sync_date
      )
    end

    it 'sends mail with expected contents' do
      expect(email).to have_subject(email_subject)
      expect(email).to have_body_text("Hello #{user.name},")
      expect(email).to have_body_text(expected_body_text)
      expect(email).to have_body_text(group_group_members_url(namespace))
      expect(email).to be_delivered_to(user.email)
    end
  end

  describe '#notify_instance_admin' do
    subject(:email) do
      described_class.notify_instance_admin(recipient: user, user_count: user_count, sync_date: sync_date)
    end

    it 'sends mail with expected contents' do
      expect(email).to have_subject(email_subject)
      expect(email).to have_body_text("Hello #{user.name},")
      expect(email).to have_body_text(expected_body_text)
      expect(email).to have_body_text(admin_users_url)
      expect(email).to be_delivered_to(user.email)
    end
  end
end
