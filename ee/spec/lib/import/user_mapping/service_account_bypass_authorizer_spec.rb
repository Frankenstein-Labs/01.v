# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Import::UserMapping::ServiceAccountBypassAuthorizer, feature_category: :importers do
  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }
  let_it_be(:another_service_account) { create(:service_account, provisioned_by_group: create(:group)) }
  let_it_be(:instance_service_account) { create(:service_account) }

  before_all do
    group.add_owner(owner)
    group.add_maintainer(maintainer)
  end

  describe '#allowed?' do
    subject(:authorizer) { described_class.new(group, assignee_user, reassigned_by_user) }

    context 'when all conditions met' do
      let(:assignee_user) { service_account }
      let(:reassigned_by_user) { owner }

      it { is_expected.to be_allowed }
    end

    context 'when assignee_user is not a service account' do
      let(:assignee_user) { user }
      let(:reassigned_by_user) { owner }

      it { is_expected.not_to be_allowed }
    end

    context 'when reassigned_by_user is not the group owner' do
      let(:assignee_user) { service_account }
      let(:reassigned_by_user) { maintainer }

      it { is_expected.not_to be_allowed }
    end

    context 'when assignee_user is a service account from a different group' do
      let(:assignee_user) { another_service_account }
      let(:reassigned_by_user) { owner }

      it { is_expected.not_to be_allowed }

      context 'when reassigned_by_user is admin and admin bypass setting is enabled', :enable_admin_mode do
        before do
          stub_application_setting(allow_bypass_placeholder_confirmation: true)
        end

        let(:reassigned_by_user) { admin }

        it { is_expected.not_to be_allowed }
      end
    end

    context 'when assignee_user is an instance-level service account' do
      let(:assignee_user) { instance_service_account }
      let(:reassigned_by_user) { admin }

      before do
        stub_application_setting(allow_bypass_placeholder_confirmation: admin_bypass_setting)
      end

      context 'when reassigned_by_user is admin and admin bypass setting is enabled', :enable_admin_mode do
        let(:admin_bypass_setting) { true }

        it { is_expected.to be_allowed }
      end

      context 'when reassigned_by_user is admin and admin bypass setting is disabled', :enable_admin_mode do
        let(:admin_bypass_setting) { false }

        it { is_expected.not_to be_allowed }
      end

      context 'when reassigned_by_user is a group owner and admin bypass setting is enabled', :enable_admin_mode do
        let(:reassigned_by_user) { owner }
        let(:admin_bypass_setting) { true }

        it { is_expected.not_to be_allowed }
      end
    end
  end
end
