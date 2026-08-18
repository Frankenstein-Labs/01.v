# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::AllRolesFinder, feature_category: :system_access do
  let_it_be(:member_role_standard) { create(:member_role, :instance, name: 'Instance role') }
  let_it_be(:member_role_admin) { create(:member_role, :admin, :instance, name: 'Admin role') }
  let_it_be(:current_user, freeze: false) { create(:admin) }

  let(:params) { {} }

  subject(:find_member_roles) { described_class.new(current_user, params).execute }

  before do
    stub_licensed_features(custom_roles: true)
  end

  context 'when the user is an admin' do
    it 'returns all roles', :enable_admin_mode do
      expect(find_member_roles).to match_array([member_role_admin, member_role_standard])
    end
  end

  context 'when the user is not an admin' do
    it 'returns standard roles' do
      expect(find_member_roles).to eq([member_role_standard])
    end
  end

  context 'when on SaaS' do
    let_it_be(:group) { create(:group) }

    let(:params) { { parent: group } }

    before do
      stub_saas_features(gitlab_com_subscriptions: true)
    end

    it 'does not return admin roles', :enable_admin_mode do
      expect(find_member_roles).not_to include(member_role_admin)
    end
  end
end
