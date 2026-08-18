# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::InventoryController, feature_category: :security_asset_inventories do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }

  before do
    stub_licensed_features(security_inventory: true)

    sign_in(user)
  end

  describe '#show', :aggregate_failures do
    subject(:request) { get group_security_inventory_path(group) }

    it_behaves_like 'internal event tracking' do
      let(:event) { 'view_group_security_inventory' }
      let(:namespace) { group }
    end

    context 'with authorized users' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_developer(user)
        sign_in(user)
      end

      it 'returns 200 response' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with unauthorized users' do
      let_it_be(:user) { create(:user) }

      before_all do
        group.add_reporter(user)
        sign_in(user)
      end

      it 'returns 403 response' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end

    context 'when security inventory feature is disabled' do
      before do
        stub_licensed_features(security_inventory: false)
      end

      it 'returns 403 response' do
        request

        expect(response).to have_gitlab_http_status(:forbidden)
      end
    end
  end
end
