# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::ServiceAccounts::UpdateService, feature_category: :user_management do
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:service_account_user) { create(:user, :service_account) }

  describe '#execute', :enable_admin_mode do
    let(:current_user) { admin }

    context 'when the ability to update name for users is disabled' do
      before do
        stub_application_setting(updating_name_disabled_for_users: true)
      end

      it 'still updates the service account name via force_name_change', :aggregate_failures do
        new_name = FFaker::Name.name
        result = described_class.new(current_user, service_account_user, name: new_name).execute

        expect(result.status).to eq(:success)
        expect(result.payload[:user].name).to eq(new_name)
      end
    end
  end
end
