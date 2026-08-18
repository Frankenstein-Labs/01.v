# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers for checking all scenarios of violations
RSpec.describe 'getting the project compliance violations for a group', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:user) { create(:user) }

  let_it_be(:root_group_project) { create(:project, group: group) }
  let_it_be(:subgroup_project) { create(:project, group: sub_group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  let_it_be(:framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }
  let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
  let_it_be(:control2) { create(:compliance_requirements_control, :external, compliance_requirement: requirement) }
  let_it_be(:control3) do
    create(:compliance_requirements_control, :default_branch_protected, compliance_requirement: requirement)
  end

  let_it_be(:other_framework) { create(:compliance_framework, namespace: other_group) }
  let_it_be(:other_requirement) { create(:compliance_requirement, namespace: other_group, framework: other_framework) }
  let_it_be(:other_control) { create(:compliance_requirements_control, compliance_requirement: other_requirement) }

  let_it_be(:audit_event1) { create(:audit_events_project_audit_event, project_id: root_group_project.id) }
  let_it_be(:audit_event2) { create(:audit_events_group_audit_event, group_id: group.id) }
  let_it_be(:audit_event3) { create(:audit_events_project_audit_event, project_id: other_project.id) }

  let_it_be(:violation1) do
    create(:project_compliance_violation, namespace: root_group_project.namespace,
      project: root_group_project,
      audit_event_id: audit_event1.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control1,
      status: 0,
      created_at: 3.days.ago
    )
  end

  let_it_be(:violation1_issue1) do
    create(:project_compliance_violation_issue, project: root_group_project, project_compliance_violation: violation1)
  end

  let_it_be(:violation1_issue2) do
    create(:project_compliance_violation_issue, project: root_group_project, project_compliance_violation: violation1)
  end

  let_it_be(:violation2) do
    create(:project_compliance_violation, namespace: root_group_project.namespace, project: root_group_project,
      audit_event_id: audit_event1.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: control2,
      status: 1
    )
  end

  let_it_be(:violation3) do
    create(:project_compliance_violation, namespace: root_group_project.namespace, project: root_group_project,
      audit_event_id: audit_event2.id,
      audit_event_table_name: :group_audit_events,
      compliance_control: control1,
      status: 2,
      created_at: 5.days.ago
    )
  end

  let_it_be(:violation4) do
    create(:project_compliance_violation, namespace: subgroup_project.namespace, project: subgroup_project,
      audit_event_id: audit_event2.id,
      audit_event_table_name: :group_audit_events,
      compliance_control: control3,
      status: 3
    )
  end

  let_it_be(:violation5) do
    create(:project_compliance_violation, namespace: other_project.namespace, project: other_project,
      audit_event_id: audit_event3.id,
      audit_event_table_name: :project_audit_events,
      compliance_control: other_control,
      status: 0
    )
  end

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        createdAt
        status
        project {
          id
          name
        }
        complianceControl {
          id
          name
        }
        issues {
          nodes {
            id
            title
          }
        }
      }
    GRAPHQL
  end

  let(:violation1_output) do
    get_violation_output(violation1)
  end

  let(:violation2_output) do
    get_violation_output(violation2)
  end

  let(:violation3_output) do
    get_violation_output(violation3)
  end

  let(:violation4_output) do
    get_violation_output(violation4)
  end

  let(:compliance_violations) { graphql_data_at(:group, :project_compliance_violations, :nodes) }

  def get_violation_output(violation)
    {
      'id' => violation.to_global_id.to_s,
      'createdAt' => violation.created_at.iso8601,
      'status' => violation.status.to_s.upcase,
      'project' => {
        'id' => violation.project.to_global_id.to_s,
        'name' => violation.project.name
      },
      'complianceControl' => {
        'id' => violation.compliance_control.to_global_id.to_s,
        'name' => violation.compliance_control.name
      },
      'issues' => {
        "nodes" => get_issues_output(violation)
      }
    }
  end

  def get_issues_output(violation)
    output = []

    violation.issues.each do |issue|
      output.prepend({
        'id' => issue.to_global_id.to_s,
        'title' => issue.title
      })
    end

    output
  end

  def query(params = {})
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field("projectComplianceViolations", params, fields)
    )
  end

  before do
    stub_licensed_features(group_level_compliance_violations_report: true)
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: user)

      expect(compliance_violations).to be_nil
    end
  end

  context 'when the user is unauthorized' do
    context 'when not part of the group' do
      it_behaves_like 'returns nil'
    end

    context 'with maintainer access' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'returns nil'
    end
  end

  context 'when the user is authorized' do
    before_all do
      group.add_owner(user)
      other_group.add_owner(user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: user)
      end
    end

    it 'finds all the project compliance violations for the group and its subgroups' do
      post_graphql(query, current_user: user)

      expect(compliance_violations).to eq(
        [violation4_output, violation2_output, violation1_output, violation3_output]
      )
    end

    context 'with filters' do
      context 'with project id filter' do
        it 'finds the filtered project compliance violations' do
          post_graphql(query({ filters: { projectId: root_group_project.to_global_id.to_s } }),
            current_user: user)

          expect(compliance_violations).to eq(
            [violation2_output, violation1_output, violation3_output]
          )
        end
      end

      context 'with control id filter' do
        it 'finds the filtered project compliance violations' do
          post_graphql(query({ filters: { controlId: control1.to_global_id.to_s } }), current_user: user)

          expect(compliance_violations).to eq(
            [violation1_output, violation3_output]
          )
        end
      end

      context 'with status filter' do
        it 'finds the filtered project compliance violations' do
          post_graphql(query({ filters: { status: [:DETECTED] } }), current_user: user)

          expect(compliance_violations).to eq(
            [violation1_output]
          )
        end
      end

      context 'with created_before filter' do
        it 'finds violations created before the specified date' do
          post_graphql(query({ filters: { createdBefore: 3.days.ago.to_date.to_s } }), current_user: user)

          expect(compliance_violations).to match_array(
            [violation1_output, violation3_output]
          )
        end
      end

      context 'with created_after filter' do
        it 'finds violations created after the specified date' do
          post_graphql(query({ filters: { createdAfter: 3.days.ago.to_date.to_s } }), current_user: user)

          expect(compliance_violations).to match_array(
            [violation4_output, violation2_output, violation1_output]
          )
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
