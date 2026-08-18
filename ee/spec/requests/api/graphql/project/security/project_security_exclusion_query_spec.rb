# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).securityExclusion', feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:exclusion_1) { create(:project_security_exclusion, :with_rule, :active, project: project) }
  let_it_be(:exclusion_2) { create(:project_security_exclusion, :with_regex_pattern, :inactive, project: project) }

  let(:args) { { id: exclusion_1.to_global_id } }
  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_graphql_field(:security_exclusion, args, all_graphql_fields_for('ProjectSecurityExclusion'))
    )
  end

  subject(:request) do
    post_graphql(
      query,
      current_user: user,
      variables: {
        fullPath: project.full_path
      }
    )
  end

  context 'when a user does not have access to the project' do
    it 'returns a null project' do
      request

      expect(graphql_data_at(:project)).to be_nil
    end
  end

  context 'when a user has access to the project' do
    context 'when user cannot read project security exclusions' do
      before_all do
        project.add_reporter(user)
      end

      it 'returns null' do
        request

        expect(graphql_data_at(:project, :security_exclusion)).to be_nil
      end
    end

    context 'when user can read project security exclusions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when feature is licensed' do
        before do
          stub_licensed_features(security_exclusions: true)
        end

        it 'returns a single exclusion filtered by its id' do
          request

          expect(graphql_data_at(:project, :security_exclusion)).to match a_graphql_entity_for(exclusion_1)
        end
      end

      context 'when feature is not licensed for the project' do
        it 'returns null' do
          request

          expect(graphql_data_at(:project, :security_exclusion)).to be_nil
        end
      end
    end
  end
end
