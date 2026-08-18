# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementStatusFinder,
  feature_category: :compliance_management do
  let_it_be(:root_group) { create(:group) }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:sub_group) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }

  let_it_be(:root_group_project) { create(:project, group: root_group) }
  let_it_be(:project1) { create(:project, group: sub_group) }
  let_it_be(:project2) { create(:project, group: sub_group) }
  let_it_be(:other_project) { create(:project, group: other_group) }

  let_it_be(:framework1) { create(:compliance_framework, namespace: root_group, name: 'framework1', color: '#ff00aa') }
  let_it_be(:framework2) { create(:compliance_framework, namespace: root_group, name: 'framework2', color: '#ff00ab') }
  let_it_be(:other_framework) do
    create(:compliance_framework, namespace: other_group, name: 'framework3', color: '#ff00ac')
  end

  let_it_be(:requirement1) do
    create(:compliance_requirement, namespace: root_group, framework: framework1, name: 'requirement1')
  end

  let_it_be(:requirement2) do
    create(:compliance_requirement, namespace: root_group, framework: framework1, name: 'requirement2')
  end

  let_it_be(:requirement3) do
    create(:compliance_requirement, namespace: root_group, framework: framework2, name: 'requirement3')
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
    create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project2)
  end

  let_it_be(:requirement_status6) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project2,
      created_at: 1.day.ago, updated_at: 1.day.ago)
  end

  let_it_be(:requirement_status7) do
    create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: project2)
  end

  let_it_be(:other_requirement_status) do
    create(:project_requirement_compliance_status, compliance_requirement: other_requirement, project: other_project)
  end

  let(:params) { {} }

  subject(:finder_response) { described_class.new(root_group, user, params).execute }

  describe '#execute' do
    before_all do
      root_group.add_owner(user)
    end

    context 'when the group is not licensed for the feature' do
      before do
        stub_licensed_features(group_level_compliance_adherence_report: false)
      end

      it { is_expected.to eq([]) }
    end

    context 'when the group is licensed for the feature' do
      before do
        stub_licensed_features(group_level_compliance_adherence_report: true)
      end

      context 'when user is not allowed to view the dashboard' do
        before_all do
          root_group.add_guest(user)
        end

        it { is_expected.to eq([]) }
      end

      context 'when user is allowed to view the dashboard' do
        it 'returns list of requirement statuses for all projects under the group in updated_at order' do
          expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
            requirement_status3, requirement_status2, requirement_status1, requirement_status6])
        end

        it 'does not return requirement statuses which are not under root group' do
          expect(finder_response.to_a).to exclude(other_requirement_status)
        end

        context 'for subgroup' do
          subject(:finder_response) { described_class.new(sub_group, user).execute }

          it 'returns list of requirement statuses for projects under subgroup' do
            expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
              requirement_status3, requirement_status6])
          end
        end

        context 'for project_id filter' do
          let(:params) { { project_id: project1.id } }

          it 'returns requirement statuses for the specified project' do
            expect(finder_response.to_a).to eq([requirement_status4, requirement_status3])
          end
        end

        context 'for requirement_id filter' do
          let(:params) { { requirement_id: requirement1.id } }

          it 'returns requirement statuses for the specified requirement' do
            expect(finder_response.to_a).to eq([requirement_status5, requirement_status3, requirement_status1])
          end
        end

        context 'for framework id filter' do
          let(:params) { { framework_id: framework1.id } }

          it 'returns requirement statuses for the specified requirement' do
            expect(finder_response.to_a).to eq([requirement_status5, requirement_status4, requirement_status3,
              requirement_status2, requirement_status1, requirement_status6])
          end
        end

        context 'for all filters' do
          let(:params) { { project_id: project1.id, requirement_id: requirement1.id, framework_id: framework1.id } }

          it 'returns requirement statuses for the specified filters' do
            expect(finder_response.to_a).to eq([requirement_status3])
          end
        end

        context 'with order_by parameter' do
          context 'when order_by is project' do
            let(:params) { { order_by: 'project' } }

            it 'returns requirement statuses ordered by project_id' do
              expect(finder_response).to eq([
                requirement_status1,
                requirement_status2,
                requirement_status3,
                requirement_status4,
                requirement_status5,
                requirement_status6,
                requirement_status7
              ])
            end
          end

          context 'when order_by is requirement' do
            let(:params) { { order_by: 'requirement' } }

            it 'returns requirement statuses ordered by requirement_id' do
              expect(finder_response).to eq([
                requirement_status1,
                requirement_status3,
                requirement_status5,
                requirement_status2,
                requirement_status4,
                requirement_status6,
                requirement_status7
              ])
            end
          end

          context 'when order_by is framework' do
            let(:params) { { order_by: 'framework' } }

            it 'returns requirement statuses ordered by framework_id' do
              expect(finder_response).to eq([
                requirement_status1,
                requirement_status2,
                requirement_status3,
                requirement_status4,
                requirement_status5,
                requirement_status6,
                requirement_status7
              ])
            end
          end

          context 'with no order_by parameter' do
            let(:params) { {} }

            it 'returns requirement statuses ordered by updated_at and id descending (default)' do
              expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
                requirement_status3, requirement_status2, requirement_status1, requirement_status6])
            end
          end

          context 'with invalid order_by parameter' do
            let(:params) { { order_by: 'invalid' } }

            it 'falls back to default ordering by updated_at and id descending' do
              expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
                requirement_status3, requirement_status2, requirement_status1, requirement_status6])
            end
          end
        end

        context 'with skip_limit parameter' do
          let(:params) { { skip_limit: true } }

          it 'returns all records without applying the default limit' do
            expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
              requirement_status3, requirement_status2, requirement_status1, requirement_status6])
          end

          it 'does not apply the outer LIMIT 100 clause to the query' do
            expect(finder_response.to_sql).not_to match(/LIMIT 100\s*\z/)
          end
        end

        context 'without skip_limit parameter' do
          let(:params) { {} }

          it 'applies the default LIMIT 100 clause to the query' do
            expect(finder_response.to_sql).to match(/LIMIT 100\s*\z/)
          end
        end
      end

      context 'when user has custom role with read_compliance_dashboard at group level' do
        let_it_be(:custom_role_user) do
          custom_role_user = create(:user)
          member_role = create(:member_role, :guest, :read_compliance_dashboard, namespace: root_group)
          create(:group_member, :guest, group: root_group, user: custom_role_user, member_role: member_role)
          custom_role_user
        end

        subject(:finder_response) { described_class.new(root_group, custom_role_user, params).execute }

        before do
          stub_licensed_features(
            group_level_compliance_adherence_report: true,
            project_level_compliance_adherence_report: true,
            custom_roles: true
          )
        end

        context 'when querying for all projects in group' do
          let(:params) { {} }

          it 'returns requirement statuses for all projects under the group' do
            expect(finder_response.to_a).to eq([requirement_status7, requirement_status5, requirement_status4,
              requirement_status3, requirement_status2, requirement_status1, requirement_status6])
          end
        end

        context 'when querying for specific project' do
          let(:params) { { project_id: project1.id } }

          it 'returns requirement statuses for the specified project' do
            expect(finder_response.to_a).to eq([requirement_status4, requirement_status3])
          end
        end

        context 'when custom_roles feature is disabled' do
          before do
            stub_licensed_features(
              group_level_compliance_adherence_report: true,
              project_level_compliance_adherence_report: true,
              custom_roles: false
            )
          end

          it 'returns empty result when custom roles are disabled' do
            expect(finder_response.to_a).to eq([])
          end
        end
      end

      context 'when user has custom role with read_compliance_dashboard at project level only' do
        let_it_be(:project_custom_role_user) do
          project_custom_role_user = create(:user)
          project_member_role = create(:member_role, :guest, :read_compliance_dashboard, namespace: root_group)
          create(:project_member, :guest, project: project1, user: project_custom_role_user,
            member_role: project_member_role)
          project_custom_role_user
        end

        subject(:finder_response) { described_class.new(root_group, project_custom_role_user, params).execute }

        before do
          stub_licensed_features(
            group_level_compliance_adherence_report: true,
            project_level_compliance_adherence_report: true,
            custom_roles: true
          )
        end

        context 'when querying for specific project user has access to' do
          let(:params) { { project_id: project1.id } }

          it 'returns requirement statuses for the project user has access to' do
            expect(finder_response.to_a).to eq([requirement_status4, requirement_status3])
          end
        end

        context 'when querying for project user does not have access to' do
          let(:params) { { project_id: project2.id } }

          it 'returns empty result for projects user has no access to' do
            expect(finder_response.to_a).to eq([])
          end
        end

        context 'when querying for all projects in group' do
          let(:params) { {} }

          it 'returns empty result as user does not have group-level access' do
            expect(finder_response.to_a).to eq([])
          end
        end

        context 'when custom_roles feature is disabled' do
          let(:params) { { project_id: project1.id } }

          before do
            stub_licensed_features(
              group_level_compliance_adherence_report: true,
              project_level_compliance_adherence_report: true,
              custom_roles: false
            )
          end

          it 'returns empty result when custom roles are disabled' do
            expect(finder_response.to_a).to eq([])
          end
        end
      end
    end
  end
end
