# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::UserMapping::EnterpriseBypassAuthorizer, feature_category: :importers do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:enterprise_user) { create(:enterprise_user, enterprise_group: group) }

  before_all do
    group.add_owner(owner)
    group.add_maintainer(maintainer)
  end

  describe '#allowed?', :saas do
    before do
      stub_licensed_features(domain_verification: domain_verification_status)

      group.namespace_settings.allow_enterprise_bypass_placeholder_confirmation =
        allow_enterprise_bypass_placeholder_confirmation
      group.namespace_settings.enterprise_bypass_expires_at = enterprise_bypass_expires_at
    end

    subject(:authorizer) { described_class.new(group, assignee_user, reassigned_by_user).allowed? }

    context 'when all conditions met' do
      let(:assignee_user) { enterprise_user }
      let(:reassigned_by_user) { owner }
      let(:domain_verification_status) { true }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { 30.days.from_now }

      it { is_expected.to be true }
    end

    context 'when domain_verification is not available' do
      let(:assignee_user) { enterprise_user }
      let(:reassigned_by_user) { owner }
      let(:domain_verification_status) { false }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { 30.days.from_now }

      it { is_expected.to be false }
    end

    context 'when assignee_user is not an enterprise user' do
      let(:assignee_user) { user }
      let(:reassigned_by_user) { owner }
      let(:domain_verification_status) { true }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { 30.days.from_now }

      it { is_expected.to be false }
    end

    context 'when reassigned_by_user is not the group owner' do
      let(:assignee_user) { enterprise_user }
      let(:reassigned_by_user) { maintainer }
      let(:domain_verification_status) { true }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { 30.days.from_now }

      it { is_expected.to be false }
    end

    context 'when namespace settings do not allow enterprise bypass' do
      let(:assignee_user) { enterprise_user }
      let(:reassigned_by_user) { owner }
      let(:domain_verification_status) { true }
      let(:allow_enterprise_bypass_placeholder_confirmation) { false }
      let(:enterprise_bypass_expires_at) { nil }

      it { is_expected.to be false }
    end

    context 'when multiple conditions are false' do
      let(:assignee_user) { user }
      let(:reassigned_by_user) { maintainer }
      let(:domain_verification_status) { false }
      let(:allow_enterprise_bypass_placeholder_confirmation) { false }
      let(:enterprise_bypass_expires_at) { nil }

      it { is_expected.to be false }
    end

    context 'when bypass is enabled but expired' do
      let(:assignee_user) { user }
      let(:reassigned_by_user) { maintainer }
      let(:domain_verification_status) { false }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { 1.day.ago }

      it { is_expected.to be false }
    end

    context 'when bypass is enabled with expiry at current time' do
      let(:assignee_user) { user }
      let(:reassigned_by_user) { maintainer }
      let(:domain_verification_status) { false }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { Time.current }

      it { is_expected.to be false }
    end

    context 'when bypass is enabled without expiry date' do
      let(:assignee_user) { user }
      let(:reassigned_by_user) { maintainer }
      let(:domain_verification_status) { false }
      let(:allow_enterprise_bypass_placeholder_confirmation) { true }
      let(:enterprise_bypass_expires_at) { nil }

      it { is_expected.to be false }
    end
  end
end
