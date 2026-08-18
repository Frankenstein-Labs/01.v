# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ServiceAccounts::GroupDeleteService, feature_category: :user_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:service_account_user) { create(:service_account, provisioned_by_group: group) }
  let_it_be(:current_user) { create(:user, owner_of: group) }

  let(:options) { { hard_delete: false } }

  subject(:service) { described_class.new(current_user, service_account_user) }

  describe '#execute' do
    context 'when current user is a group owner' do
      context 'when allow_top_level_group_owners_to_create_service_accounts is disabled' do
        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
        end

        it_behaves_like 'service account deletion failure'

        context 'when saas', :saas do
          it_behaves_like 'service account deletion failure'
        end
      end

      context 'when allow_top_level_group_owners_to_create_service_accounts is enabled' do
        before do
          stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        end

        it_behaves_like 'service account deletion success'

        context 'when saas', :saas do
          it_behaves_like 'service account deletion success'
        end

        context 'when service account is provisioned by a subgroup' do
          let_it_be(:subgroup) { create(:group, :private, parent: create(:group)) }
          let_it_be(:service_account_user) { create(:service_account, provisioned_by_group: subgroup) }

          it_behaves_like 'service account deletion failure'
        end
      end
    end
  end
end
