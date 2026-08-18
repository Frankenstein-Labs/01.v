# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::AdminRolesFinder, feature_category: :system_access do
  let_it_be(:member_role_standard) { create(:member_role, :instance, name: 'Instance role') }
  let_it_be(:member_role_admin) { create(:member_role, :admin, :instance, name: 'Admin role') }
  let_it_be(:current_user, freeze: false) { create(:admin) }
  let(:params) { {} }

  subject(:find_member_roles) { described_class.new(current_user, params).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  context 'when on self-managed' do
    context 'when the user is an admin' do
      it 'returns only admin member roles', :enable_admin_mode do
        expect(find_member_roles).to eq([member_role_admin])
      end
    end

    context 'when the user is not an admin' do
      it 'returns an empty array' do
        expect(find_member_roles).to be_empty
      end
    end
  end

  context 'when on SaaS' do
    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it 'returns only admin member roles', :enable_admin_mode do
      expect(find_member_roles).to eq([member_role_admin])
    end

    context 'with parent param' do
      let_it_be(:group) { create(:group) }

      let(:params) { { parent: group } }

      it 'returns an empty array', :enable_admin_mode do
        expect(find_member_roles).to be_empty
      end
    end
  end
end
