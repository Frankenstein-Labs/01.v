# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).securityPolicyEligibleProjects',
  feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:top_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: top_group) }
  let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
  let_it_be(:project_in_top_group) { create(:project, group: top_group) }
  let_it_be(:security_policy_project) do
    create(:project, security_policy_project_linked_groups: [subgroup])
  end

  let(:args) { {} }
  let(:query) do
    graphql_query_for(
      :project,
      { full_path: security_policy_project.full_path },
      query_nodes(:security_policy_eligible_projects, 'id', args: args)
    )
  end

  let(:eligible_projects_data) do
    graphql_data_at(:project, :security_policy_eligible_projects, :nodes)
  end

  subject(:request) do
    post_graphql(query, current_user: user)
  end

  before_all do
    security_policy_project.add_developer(user)
    top_group.add_developer(user)
  end

  context 'when feature is not licensed' do
    it 'returns empty nodes' do
      request

      expect(eligible_projects_data).to be_empty
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(security_orchestration_policies: true)
    end

    it 'returns eligible projects from root ancestor hierarchy' do
      request

      expect(eligible_projects_data).to include(
        a_graphql_entity_for(project_in_subgroup),
        a_graphql_entity_for(project_in_top_group)
      )
    end

    context 'with search argument' do
      let(:args) { { search: project_in_subgroup.name } }

      it 'filters projects by search term' do
        request

        expect(eligible_projects_data).to include(a_graphql_entity_for(project_in_subgroup))
        expect(eligible_projects_data).not_to include(a_graphql_entity_for(project_in_top_group))
      end
    end

    context 'with ids argument' do
      let(:args) { { ids: [project_in_subgroup.to_gid.to_s] } }

      it 'returns only the requested eligible projects' do
        request

        expect(eligible_projects_data).to contain_exactly(a_graphql_entity_for(project_in_subgroup))
      end

      context 'when a requested id is not eligible' do
        let_it_be(:unrelated_project) { create(:project) }

        let(:args) { { ids: [unrelated_project.to_gid.to_s] } }

        before_all do
          unrelated_project.add_developer(user)
        end

        it 'excludes the ineligible project' do
          request

          expect(eligible_projects_data).to be_empty
        end
      end
    end

    context 'when user has no access to group projects' do
      let_it_be(:unauthorized_user) { create(:user) }

      before_all do
        security_policy_project.add_developer(unauthorized_user)
      end

      subject(:request) do
        post_graphql(query, current_user: unauthorized_user)
      end

      it 'returns empty eligible projects' do
        request

        expect(eligible_projects_data).to be_empty
      end
    end

    context 'when security policy project has no linked groups' do
      let_it_be(:unlinked_spp) { create(:project) }

      let(:query) do
        graphql_query_for(
          :project,
          { full_path: unlinked_spp.full_path },
          query_nodes(:security_policy_eligible_projects, 'id')
        )
      end

      before_all do
        unlinked_spp.add_developer(user)
      end

      it 'returns empty nodes' do
        request

        expect(graphql_data_at(:project, :security_policy_eligible_projects, :nodes)).to be_empty
      end
    end
  end
end
