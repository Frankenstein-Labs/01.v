# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).securityExclusions', feature_category: :secret_detection do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be(:exclusion_1) { create(:project_security_exclusion, :with_rule, :active, project: project) }
  let_it_be(:exclusion_2) { create(:project_security_exclusion, :with_regex_pattern, :inactive, project: project) }
  let_it_be(:exclusion_3) { create(:project_security_exclusion, :with_path, :active, project: project) }

  let(:args) { {} }
  let(:query) do
    graphql_query_for(
      :project,
      { full_path: project.full_path },
      query_nodes(:security_exclusions, all_graphql_fields_for('ProjectSecurityExclusion'), args: args)
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

        expect(graphql_data_at(:project, :security_exclusions)).to be_nil
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

        it 'returns all security exclusions' do
          request

          expect(graphql_data_at(:project, :security_exclusions, :nodes)).to contain_exactly(
            a_graphql_entity_for(exclusion_1),
            a_graphql_entity_for(exclusion_2),
            a_graphql_entity_for(exclusion_3)
          )
        end

        context 'when filtering by scanner' do
          let(:args) do
            { scanner: :SECRET_PUSH_PROTECTION }
          end

          it 'returns all exclusions for that scanner' do
            request

            expect(graphql_data_at(:project, :security_exclusions, :nodes)).to contain_exactly(
              a_graphql_entity_for(exclusion_1),
              a_graphql_entity_for(exclusion_2),
              a_graphql_entity_for(exclusion_3)
            )
          end
        end

        context 'when filtering by type' do
          let(:args) { { type: :PATH } }

          it 'returns all exclusions for that type' do
            request

            expect(graphql_data_at(:project, :security_exclusions, :nodes)).to contain_exactly(
              a_graphql_entity_for(exclusion_3)
            )
          end
        end

        context 'when filtering by status' do
          let(:args) { { active: false } }

          it 'returns all exclusions for that status' do
            request

            expect(graphql_data_at(:project, :security_exclusions, :nodes)).to contain_exactly(
              a_graphql_entity_for(exclusion_2)
            )
          end
        end
      end

      context 'when feature is not licensed for the project' do
        it 'returns null' do
          request

          expect(graphql_data_at(:project, :security_exclusions)).to be_nil
        end
      end
    end
  end
end
