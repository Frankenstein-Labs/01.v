# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the requirement control coverage for a group', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: sub_group) }

  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement1) { create(:compliance_requirement, framework: framework, namespace: group) }
  let_it_be(:requirement2) { create(:compliance_requirement, framework: framework, namespace: group) }

  let_it_be(:control1) { create(:compliance_requirements_control, :external, compliance_requirement: requirement1) }
  let_it_be(:control2) do
    create(:compliance_requirements_control, :minimum_approvals_required_2, compliance_requirement: requirement1)
  end

  let_it_be(:control3) do
    create(:compliance_requirements_control, :project_visibility_not_internal, compliance_requirement: requirement2)
  end

  let(:fields) do
    <<~GRAPHQL
      passed
      failed
      pending
    GRAPHQL
  end

  let(:control_coverage) { graphql_data_at(:group, :compliance_requirement_control_coverage) }

  def query
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field("complianceRequirementControlCoverage", {}, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_dashboard: true)
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(control_coverage).to be_nil
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
          query_graphql_field("complianceRequirementControlCoverage", {}, fields)
        )
      end

      before_all do
        empty_group.add_owner(current_user)
      end

      it 'returns nil' do
        post_graphql(empty_group_query, current_user: current_user)

        expect(control_coverage).to eq({
          "failed" => 0,
          "passed" => 0,
          "pending" => 0
        })
      end
    end

    context 'when group has control statuses' do
      before do
        create(:compliance_framework_project_setting,
          project: project1,
          compliance_management_framework: framework)
        create(:compliance_framework_project_setting,
          project: project2,
          compliance_management_framework: framework)

        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control1,
          compliance_requirement: requirement1,
          status: :pass)
        create(:project_control_compliance_status,
          project: project2,
          compliance_requirements_control: control1,
          compliance_requirement: requirement1,
          status: :pass)

        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control2,
          compliance_requirement: requirement1,
          status: :fail)

        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control3,
          compliance_requirement: requirement2,
          status: :pending)
        create(:project_control_compliance_status,
          project: project2,
          compliance_requirements_control: control2,
          compliance_requirement: requirement1,
          status: :pending)
      end

      it 'returns the correct control coverage counts' do
        post_graphql(query, current_user: current_user)

        expect(control_coverage).to eq({
          'passed' => 2,
          'failed' => 1,
          'pending' => 2
        })
      end
    end

    context 'when all controls pass' do
      before do
        create(:compliance_framework_project_setting,
          project: project1,
          compliance_management_framework: framework)

        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control1,
          compliance_requirement: requirement1,
          status: :pass)
        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control2,
          compliance_requirement: requirement1,
          status: :pass)
      end

      it 'returns all controls as passed' do
        post_graphql(query, current_user: current_user)

        expect(control_coverage).to eq({
          'passed' => 2,
          'failed' => 0,
          'pending' => 0
        })
      end
    end

    context 'when no control statuses exist' do
      it 'returns zeros for all counts' do
        post_graphql(query, current_user: current_user)

        expect(control_coverage).to eq({
          'passed' => 0,
          'failed' => 0,
          'pending' => 0
        })
      end
    end
  end
end
