# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCapMailer, feature_category: :seat_cost_management do
  include EmailSpec::Matchers

  describe '#over_limit_email', :with_trial_types do
    let(:namespace) { build(:namespace) }
    let(:user) { build(:user) }

    subject(:email) { described_class.over_limit_email(user, namespace) }

    it 'creates an email message namespace being over free user cap', :aggregate_failures do
      stub_ee_application_setting(dashboard_limit: 5)

      result = format(
        s_('FreeUserCap|Action required: %{namespace_name} group has been placed into a read-only state'),
        namespace_name: namespace.name
      )
      expect(email).to have_subject(result)
      expect(email).to have_body_text(s_("FreeUserCap|You've exceeded your user limit"))
      expect(email).to have_body_text(s_('FreeUserCap|You have exceeded your limit'))
      expect(email).to have_body_text(s_('FreeUserCap|of 5 users'))
      expect(email).to have_body_text(s_('FreeUserCap|Manage members'))
      expect(email).to have_body_text(s_('FreeUserCap|Explore paid plans'))
      expect(email).to have_body_text("#{namespace.name}/-/billings")
      expect(email).to have_body_text('usage_quotas#seats-quota-tab')
      expect(email).to have_body_text('-/trials/new')
      expect(email).to be_delivered_to([user.notification_email_or_default])
    end
  end
end
