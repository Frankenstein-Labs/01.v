# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/FactoryBot/AvoidCreate -- enrollment checks require DB persistence
RSpec.describe 'Querying namespace secrets manager enrollment', feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:nested_subgroup) { create(:group, parent: subgroup) }
  let_it_be(:current_user) { create(:user) }

  let(:namespace_path) { root_group.full_path }
  let(:query) do
    graphql_query_for(
      :namespace_secrets_manager_enrollment,
      { namespace_path: namespace_path },
      'namespace { id fullPath } beta'
    )
  end

  subject(:resolved_data) do
    post_graphql(query, current_user: current_user)
    graphql_data_at(:namespace_secrets_manager_enrollment)
  end

  before_all do
    root_group.add_owner(current_user)
  end

  before do
    stub_licensed_features(native_secrets_management: true)
  end

  context 'when on GitLab.com', :saas do
    context 'when root group is enrolled' do
      let(:beta) { true }

      before do
        create(:secrets_manager_namespace_enrollment, namespace: root_group, beta: beta)
      end

      it 'returns the enrollment for the root group itself' do
        expect(resolved_data['namespace']['fullPath']).to eq(root_group.full_path)
      end

      it 'returns the beta cohort marker' do
        expect(resolved_data['beta']).to be true
      end

      context 'when the enrollment is not part of the beta cohort' do
        let(:beta) { false }

        it 'returns false' do
          expect(resolved_data['beta']).to be false
        end
      end

      context 'when querying a subgroup' do
        let(:namespace_path) { subgroup.full_path }

        it 'returns null (resolver only accepts root namespace paths)' do
          expect(resolved_data).to be_nil
        end
      end

      context 'when querying a deeply nested subgroup' do
        let(:namespace_path) { nested_subgroup.full_path }

        it 'returns null (resolver only accepts root namespace paths)' do
          expect(resolved_data).to be_nil
        end
      end
    end

    context 'when root group is not enrolled' do
      it 'returns null' do
        expect(resolved_data).to be_nil
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
