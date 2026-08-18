# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting the compliance control statuses for a project',
  feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }

  let_it_be(:compliance_requirement1) { create(:compliance_requirement, framework: compliance_framework) }
  let_it_be(:compliance_requirement_control1) do
    create(:compliance_requirements_control,
      compliance_requirement: compliance_requirement1)
  end

  let_it_be(:control_status1) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirements_control: compliance_requirement_control1,
      compliance_requirement: compliance_requirement1)
  end

  let_it_be(:compliance_requirement2) { create(:compliance_requirement, framework: compliance_framework) }
  let_it_be(:compliance_requirement_control2) do
    create(:compliance_requirements_control,
      compliance_requirement: compliance_requirement2)
  end

  let_it_be(:control_status2) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirements_control: compliance_requirement_control2,
      compliance_requirement: compliance_requirement2)
  end

  let_it_be(:compliance_requirement3) { create(:compliance_requirement, framework: compliance_framework) }

  let_it_be(:project2_control_status) do
    create(:project_control_compliance_status, project: project2)
  end

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
      	status
        updatedAt
        complianceRequirementsControl {
          id
          name
        }
      }
    GRAPHQL
  end

  let(:control_statuses) { graphql_data_at(:project, :compliance_control_status, :nodes) }

  def control_status_output(control_status)
    {
      'id' => control_status.to_global_id.to_s,
      'status' => control_status.status.upcase,
      'updatedAt' => control_status.updated_at.iso8601,
      'complianceRequirementsControl' => {
        'id' => control_status.compliance_requirements_control.to_global_id.to_s,
        'name' => control_status.compliance_requirements_control.name
      }
    }
  end

  def query(params = {})
    graphql_query_for(
      :project, { full_path: project.full_path },
      query_graphql_field("complianceControlStatus", params, fields)
    )
  end

  before do
    stub_licensed_features(project_level_compliance_dashboard: true, project_level_compliance_adherence_report: true)
  end

  context 'when the user is authorized' do
    before_all do
      project.add_owner(current_user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    context 'without any filters' do
      it 'finds all the compliance control statuses for the project' do
        post_graphql(query, current_user: current_user)

        expect(control_statuses).to eq([
          control_status_output(control_status1),
          control_status_output(control_status2)
        ])
      end
    end

    context 'with filters' do
      context 'when given requirement id' do
        context 'when the input is valid' do
          it 'finds the filtered compliance control statuses' do
            post_graphql(query({ filters: { complianceRequirementId: compliance_requirement1.to_global_id } }),
              current_user: current_user)

            expect(control_statuses).to eq([control_status_output(control_status1)])
          end
        end

        context 'when the input is not valid' do
          context 'when requirement id do not have control status for the project' do
            it 'returns empty response' do
              post_graphql(query({ filters: { complianceRequirementId: compliance_requirement3.to_global_id } }),
                current_user: current_user)

              expect(control_statuses).to eq([])
            end
          end

          context 'when non existing requirement id provided' do
            let(:non_existent_requirement_id) do
              "gid://gitlab/ComplianceManagement::ComplianceFramework::ComplianceRequirement/#{non_existing_record_id}"
            end

            it 'returns empty response' do
              post_graphql(query({ filters: { complianceRequirementId: non_existent_requirement_id } }),
                current_user: current_user)

              expect(control_statuses).to eq([])
            end
          end
        end
      end
    end
  end
end
