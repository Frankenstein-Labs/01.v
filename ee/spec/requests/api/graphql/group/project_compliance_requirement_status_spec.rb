# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers for checking all scenarios of requirement statuses
RSpec.describe 'getting the project compliance requirement statuses for a group',
  feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: group) }
  let_it_be(:current_user) { create(:user) }

  let_it_be(:root_group_project) { create(:project, group: group) }
  let_it_be(:project1) { create(:project, group: sub_group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  let_it_be(:framework1) { create(:compliance_framework, namespace: group, name: 'framework1', color: '#ff00aa') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: group, name: 'framework2', color: '#ff00ab') }
  let_it_be(:other_framework) do
    create(:compliance_framework, namespace: other_group, name: 'other_framework', color: '#ff00ac')
  end

  let_it_be(:requirement1) do
    create(:compliance_requirement, namespace: group, framework: framework1, name: 'requirement1')
  end

  let_it_be(:requirement2) do
    create(:compliance_requirement, namespace: group, framework: framework1, name: 'requirement2')
  end

  let_it_be(:requirement3) do
    create(:compliance_requirement, namespace: group, framework: framework2, name: 'requirement3')
  end

  let_it_be(:other_requirement) do
    create(:compliance_requirement, namespace: other_group, framework: other_framework, name: 'other_requirement')
  end

  let_it_be(:requirement_status1) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: root_group_project)
  end

  let_it_be(:requirement_status2) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: root_group_project)
  end

  let_it_be(:requirement_status3) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project1)
  end

  let_it_be(:requirement_status4) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project1)
  end

  let_it_be(:requirement_status5) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: root_group_project)
  end

  let_it_be(:requirement_status6) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: project1)
  end

  let_it_be(:other_requirement_status) do
    create(:project_requirement_compliance_status, compliance_requirement: other_requirement, project: other_project)
  end

  let(:fields) do
    <<~GRAPHQL
      nodes {
        id
        updatedAt
        passCount
        failCount
        pendingCount
        project {
          id
          name
        }
        complianceRequirement {
          id
          name
        }
        complianceFramework {
          id
          name
          color
          editPath
        }
      }
    GRAPHQL
  end

  let(:requirement_status1_output) do
    get_requirement_status_output(requirement_status1)
  end

  let(:requirement_status2_output) do
    get_requirement_status_output(requirement_status2)
  end

  let(:requirement_status3_output) do
    get_requirement_status_output(requirement_status3)
  end

  let(:requirement_status4_output) do
    get_requirement_status_output(requirement_status4)
  end

  let(:requirement_status5_output) do
    get_requirement_status_output(requirement_status5)
  end

  let(:requirement_status6_output) do
    get_requirement_status_output(requirement_status6)
  end

  let(:requirement_statuses) { graphql_data_at(:group, :project_compliance_requirements_status, :nodes) }

  def get_requirement_status_output(requirement_status)
    {
      'id' => requirement_status.to_global_id.to_s,
      'updatedAt' => requirement_status.updated_at.iso8601,
      'passCount' => requirement_status.pass_count,
      'failCount' => requirement_status.fail_count,
      'pendingCount' => requirement_status.pending_count,
      'project' => {
        'id' => requirement_status.project.to_global_id.to_s,
        'name' => requirement_status.project.name
      },
      'complianceRequirement' => {
        'id' => requirement_status.compliance_requirement.to_global_id.to_s,
        'name' => requirement_status.compliance_requirement.name
      },
      'complianceFramework' => {
        'id' => requirement_status.compliance_framework.to_global_id.to_s,
        'name' => requirement_status.compliance_framework.name,
        'color' => requirement_status.compliance_framework.color,
        'editPath' => edit_path(requirement_status, group)
      }
    }
  end

  def edit_path(requirement_status, group)
    "/groups/#{group.name}/-/security/compliance_dashboard/frameworks/#{requirement_status.compliance_framework.id}"
  end

  def query(params = {})
    graphql_query_for(
      :group, { full_path: group.full_path },
      query_graphql_field("projectComplianceRequirementsStatus", params, fields)
    )
  end

  before do
    stub_licensed_features(
      custom_compliance_frameworks: true,
      group_level_compliance_adherence_report: true,
      project_level_compliance_adherence_report: true
    )
  end

  shared_examples 'returns nil' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(requirement_statuses).to be_nil
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

    context 'without any filters' do
      it 'finds all the project compliance requirement statuses for the group and its subgroups' do
        post_graphql(query, current_user: current_user)

        expect(requirement_statuses).to eq(
          [requirement_status6_output, requirement_status5_output, requirement_status4_output,
            requirement_status3_output, requirement_status2_output, requirement_status1_output]
        )
      end
    end

    context 'with filters' do
      context 'with project id filter' do
        context 'when the project has compliance requirement statuses' do
          it 'finds the filtered project compliance requirement statuses' do
            post_graphql(query({ filters: { projectId: root_group_project.to_global_id.to_s } }),
              current_user: current_user)

            expect(requirement_statuses).to match_array([requirement_status5_output, requirement_status2_output,
              requirement_status1_output])
          end
        end

        context 'when the project does not have compliance requirement statuses' do
          let_it_be(:project_without_status) { create(:project, group: group) }

          it 'returns an empty array' do
            post_graphql(query({ filters: { projectId: project_without_status.to_global_id.to_s } }),
              current_user: current_user)

            expect(requirement_statuses).to be_empty
          end
        end

        context 'when the project id is not existent' do
          let(:non_existent_project_id) { "gid://gitlab/Project/#{non_existing_record_id}" }

          it 'returns an empty array' do
            post_graphql(query({ filters: { projectId: non_existent_project_id } }), current_user: current_user)

            expect(requirement_statuses).to be_empty
          end
        end
      end

      context 'with requirement id filter' do
        context 'when the requirement has compliance requirement statuses' do
          it 'finds the filtered project compliance requirement statuses' do
            post_graphql(query({ filters: { requirementId: requirement1.to_global_id.to_s } }),
              current_user: current_user)

            expect(requirement_statuses).to match_array([requirement_status3_output, requirement_status1_output])
          end
        end

        context 'when the requirement does not have compliance requirement statuses' do
          let_it_be(:requirement_without_status) do
            create(:compliance_requirement, namespace: group, framework: framework1, name: 'requirement_without_status')
          end

          it 'returns an empty array' do
            post_graphql(query({ filters: { requirementId: requirement_without_status.to_global_id.to_s } }),
              current_user: current_user)

            expect(requirement_statuses).to be_empty
          end
        end

        context 'when the requirement id is not existent' do
          let(:non_existent_requirement_id) do
            "gid://gitlab/ComplianceManagement::ComplianceFramework::ComplianceRequirement/#{non_existing_record_id}"
          end

          it 'returns an empty array' do
            post_graphql(query({ filters: { requirementId: non_existent_requirement_id } }), current_user: current_user)

            expect(requirement_statuses).to be_empty
          end
        end
      end

      context 'with framework id filter' do
        context 'when the framework has compliance requirement statuses' do
          it 'finds the filtered project compliance requirement statuses' do
            post_graphql(query({ filters: { frameworkId: framework1.to_global_id.to_s } }),
              current_user: current_user)

            expect(requirement_statuses).to match_array([requirement_status4_output, requirement_status3_output,
              requirement_status2_output, requirement_status1_output])
          end
        end

        context 'when the framework does not have compliance requirement statuses' do
          let_it_be(:framework_without_status) do
            create(:compliance_framework, namespace: group, name: 'framework_without_status', color: '#ff00ae')
          end

          it 'returns an empty array' do
            post_graphql(query({ filters: { frameworkId: framework_without_status.to_global_id.to_s } }),
              current_user: current_user)

            expect(requirement_statuses).to be_empty
          end
        end

        context 'when the framework id is not existent' do
          let(:non_existent_framework_id) { "gid://gitlab/ComplianceManagement::Framework/#{non_existing_record_id}" }

          it 'returns an empty array' do
            post_graphql(query({ filters: { frameworkId: non_existent_framework_id } }), current_user: current_user)

            expect(requirement_statuses).to be_empty
          end
        end
      end

      context 'with all filters' do
        it 'returns filtered statuses' do
          post_graphql(
            query(
              {
                filters: {
                  projectId: root_group_project.to_global_id.to_s,
                  requirementId: requirement1.to_global_id.to_s,
                  frameworkId: framework1.to_global_id.to_s
                }
              }
            ),
            current_user: current_user
          )

          expect(requirement_statuses).to match_array([requirement_status1_output])
        end
      end
    end

    context 'with ordering' do
      context 'when ordered by projects' do
        it 'returns requirement statuses ordered by projects' do
          post_graphql(query({ orderBy: :PROJECT }), current_user: current_user)

          expect(requirement_statuses).to eq([requirement_status1_output, requirement_status2_output,
            requirement_status5_output, requirement_status3_output, requirement_status4_output,
            requirement_status6_output])
        end
      end

      context 'when ordered by requirements' do
        it 'returns requirement statuses ordered by requirements' do
          post_graphql(query({ orderBy: :REQUIREMENT }), current_user: current_user)

          expect(requirement_statuses).to eq([requirement_status1_output, requirement_status3_output,
            requirement_status2_output, requirement_status4_output, requirement_status5_output,
            requirement_status6_output])
        end
      end

      context 'when ordered by frameworks' do
        it 'returns requirement statuses ordered by frameworks' do
          post_graphql(query({ orderBy: :FRAMEWORK }), current_user: current_user)

          expect(requirement_statuses).to eq([requirement_status1_output, requirement_status2_output,
            requirement_status3_output, requirement_status4_output, requirement_status5_output,
            requirement_status6_output])
        end
      end

      context 'when order_by is invalid' do
        it 'returns requirement statuses ordered by frameworks' do
          post_graphql(query({ orderBy: :INVALID }), current_user: current_user)

          expect_graphql_errors_to_include(
            "Argument 'orderBy' on Field 'projectComplianceRequirementsStatus' has an invalid value (INVALID). " \
              "Expected type 'ProjectComplianceRequirementStatusOrderBy'.")
        end
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
