# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the requirement coverage for a group', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: sub_group) }

  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement1) { create(:compliance_requirement, framework: framework, namespace: group) }
  let_it_be(:requirement2) { create(:compliance_requirement, framework: framework, namespace: group) }

  let(:fields) do
    <<~GRAPHQL
      passed
      failed
      pending
    GRAPHQL
  end

  let(:requirement_coverage) { graphql_data_at(:group, :compliance_requirement_coverage) }

  def query
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field("complianceRequirementCoverage", {}, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(requirement_coverage).to be_nil
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

    context 'when group has no projects' do
      let_it_be(:empty_group) { create(:group) }

      def empty_group_query
        graphql_query_for(
          :group, { full_path: empty_group.full_path },
          query_graphql_field("complianceRequirementCoverage", {}, fields)
        )
      end

      before_all do
        empty_group.add_owner(current_user)
      end

      it 'returns nil' do
        post_graphql(empty_group_query, current_user: current_user)

        expect(graphql_data_at(:group, :compliance_requirement_coverage)).to eq({ "failed" => 0,
                                                                                  "passed" => 0,
                                                                                  "pending" => 0 })
      end
    end

    context 'when group has requirement statuses' do
      before do
        create(:project_requirement_compliance_status,
          project: project1,
          compliance_requirement: requirement1,
          pass_count: 5,
          fail_count: 0,
          pending_count: 0)

        create(:project_requirement_compliance_status,
          project: project1,
          compliance_requirement: requirement2,
          pass_count: 3,
          fail_count: 2,
          pending_count: 0)

        create(:project_requirement_compliance_status,
          project: project2,
          compliance_requirement: requirement1,
          pass_count: 2,
          fail_count: 0,
          pending_count: 3)
      end

      it 'returns the correct requirement coverage' do
        post_graphql(query, current_user: current_user)

        expect(requirement_coverage).to eq({
          'passed' => 1,
          'failed' => 1,
          'pending' => 1
        })
      end
    end

    context 'when all requirements pass' do
      before do
        create(:project_requirement_compliance_status,
          project: project1,
          compliance_requirement: requirement1,
          pass_count: 5,
          fail_count: 0,
          pending_count: 0)

        create(:project_requirement_compliance_status,
          project: project2,
          compliance_requirement: requirement2,
          pass_count: 3,
          fail_count: 0,
          pending_count: 0)
      end

      it 'returns all requirements as passed' do
        post_graphql(query, current_user: current_user)

        expect(requirement_coverage).to eq({
          'passed' => 2,
          'failed' => 0,
          'pending' => 0
        })
      end
    end

    context 'when no requirement statuses exist' do
      it 'returns zeros for all counts' do
        post_graphql(query, current_user: current_user)

        expect(requirement_coverage).to eq({
          'passed' => 0,
          'failed' => 0,
          'pending' => 0
        })
      end
    end
  end
end
