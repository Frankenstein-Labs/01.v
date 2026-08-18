# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Clearing an admin-locked GitLab Duo availability override', feature_category: :ai_abstraction_layer do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }

  let(:current_user) { admin }
  let(:group_gid) { group.to_global_id.to_s }

  let(:mutation_params) do
    {
      groupId: group_gid
    }
  end

  let(:mutation_name) { :admin_clear_duo_availability }
  let(:mutation) { graphql_mutation(mutation_name, mutation_params) }

  before_all do
    group.add_owner(owner)
  end

  before do
    group.namespace_settings.update!(
      duo_features_enabled: false,
      lock_duo_features_enabled: true,
      admin_locked_duo_features_enabled: true
    )
  end

  subject(:request) { post_graphql_mutation(mutation, current_user: current_user) }

  describe '#resolve' do
    context 'when the user is not an admin' do
      let(:current_user) { owner }

      it_behaves_like 'a mutation on an unauthorized resource'
    end

    context 'when the user is an admin', :enable_admin_mode do
      it 'clears the admin-locked override' do
        request

        result = graphql_mutation_response(mutation_name)

        expect(result['errors']).to eq([])
        expect(result['adminLocked']).to be(false)

        setting = group.namespace_settings.reload
        expect(setting.admin_locked_duo_features_enabled).to be(false)
        # Assert the raw columns: `duo_features_enabled` is reset to nil so the
        # cascading reader re-resolves it; the lock is unlocked (NOT NULL -> false).
        expect(setting.read_attribute(:duo_features_enabled)).to be_nil
        expect(setting.read_attribute(:lock_duo_features_enabled)).to be(false)
      end
    end
  end
end
