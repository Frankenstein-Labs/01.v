# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::AdminRoles::UpdateService, feature_category: :permissions do
  let_it_be(:regular_user) { create(:user) }
  let_it_be(:admin) { create(:admin) }

  let(:user) { regular_user }

  # used in tracking custom role action shard examples
  let(:namespace) { nil }

  describe '#execute' do
    let_it_be(:existing_abilities) { Gitlab::CustomRoles::Definition.admin.keys.sample(3).index_with(true) }
    let(:updated_abilities) { existing_abilities.merge(existing_abilities.each_key.first => false) }
    let(:params) do
      {
        name: role_name,
        description: role_description,
        **updated_abilities
      }
    end

    let(:role_name) { 'new name' }
    let(:role_description) { 'new description' }

    subject(:result) { described_class.new(user, params).execute(role) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when admin role', :enable_admin_mode do
      let_it_be_with_reload(:role) { create(:admin_role, **existing_abilities) }

      context 'with unauthorized user' do
        let(:user) { regular_user }

        it 'returns an error' do
          expect(result).to be_error
        end
      end

      context 'with authorized user' do
        let(:user) { admin }

        it_behaves_like 'custom role update' do
          let(:audit_event_message) { 'Custom admin role was updated' }
          let(:audit_event_type) { 'custom_admin_role_updated' }
        end

        it_behaves_like 'tracking custom role action', 'update_admin'
      end
    end
  end
end
