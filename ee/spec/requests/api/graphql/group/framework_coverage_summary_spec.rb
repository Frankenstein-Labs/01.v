# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the framework coverage summary for a group', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:root_group_project) { create(:project, group: group) }
  let_it_be(:sub_group_project) { create(:project, group: sub_group) }
  let_it_be(:uncovered_project) { create(:project, group: group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  let_it_be(:framework1) { create(:compliance_framework, namespace: group, name: 'framework1') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: group, name: 'framework2') }

  let(:fields) do
    <<~GRAPHQL
      totalProjects
      coveredCount
    GRAPHQL
  end

  let(:coverage_summary) { graphql_data_at(:group, :compliance_framework_coverage_summary) }

  def query
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field("complianceFrameworkCoverageSummary", {}, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(coverage_summary).to be_nil
    end
  end

  context 'when the user is unauthorized' do
    context 'when not part of the group' do
      it_behaves_like 'returns nil'
    end

    context 'with maintainer access' do
      before_all do
        group.add_maintainer(current_user)
      end

      it_behaves_like 'returns nil'
    end
  end

  context 'when the user is authorized' do
    before_all do
      group.add_owner(current_user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    context 'when group has projects with framework coverage' do
      before do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework1,
          project: root_group_project)
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework2,
          project: root_group_project)
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework1,
          project: sub_group_project)
      end

      it 'returns the correct framework coverage summary' do
        post_graphql(query, current_user: current_user)

        expect(coverage_summary).to eq({
          'totalProjects' => 3,
          'coveredCount' => 2
        })
      end
    end

    context 'when group has no projects' do
      let_it_be(:empty_group) { create(:group) }

      def empty_group_query
        graphql_query_for(
          :group, { full_path: empty_group.full_path },
          query_graphql_field("complianceFrameworkCoverageSummary", {}, fields)
        )
      end

      before_all do
        empty_group.add_owner(current_user)
      end

      it 'returns nil' do
        post_graphql(empty_group_query, current_user: current_user)

        expect(graphql_data_at(:group, :compliance_framework_coverage_summary)).to eq({
          'totalProjects' => 0,
          'coveredCount' => 0
        })
      end
    end

    context 'when all projects are covered' do
      before do
        create(:compliance_framework_project_setting,
          project: root_group_project,
          compliance_management_framework: framework1)
        create(:compliance_framework_project_setting,
          project: sub_group_project,
          compliance_management_framework: framework1)
        create(:compliance_framework_project_setting,
          project: uncovered_project,
          compliance_management_framework: framework1)
      end

      it 'returns correct coverage summary' do
        post_graphql(query, current_user: current_user)

        expect(coverage_summary).to eq({
          'totalProjects' => 3,
          'coveredCount' => 3
        })
      end
    end

    context 'when no projects are covered' do
      it 'returns coverage summary with all projects covered' do
        post_graphql(query, current_user: current_user)

        expect(coverage_summary).to eq({
          'totalProjects' => 3,
          'coveredCount' => 0
        })
      end
    end

    context 'when project has multiple framework assignments' do
      before do
        create(:compliance_framework_project_setting,
          project: root_group_project,
          compliance_management_framework: framework1)
        create(:compliance_framework_project_setting,
          project: root_group_project,
          compliance_management_framework: framework2)
      end

      it 'counts project only once in coverage' do
        post_graphql(query, current_user: current_user)

        expect(coverage_summary).to eq({
          'totalProjects' => 3,
          'coveredCount' => 1
        })
      end
    end
  end
end
