# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectControlStatusFinder,
  feature_category: :compliance_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
  let_it_be(:compliance_requirement) { create(:compliance_requirement, framework: compliance_framework) }
  let_it_be(:compliance_requirement2) do
    create(:compliance_requirement, framework: compliance_framework, name: 'requirement2')
  end

  let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: compliance_requirement) }
  let_it_be(:control2) do
    create(:compliance_requirements_control, :external, compliance_requirement: compliance_requirement2)
  end

  let_it_be(:control_status) do
    create(:project_control_compliance_status,
      project: project,
      compliance_requirement: compliance_requirement,
      compliance_requirements_control: control1)
  end

  let_it_be(:another_control_status) do
    create(:project_control_compliance_status, project: project, compliance_requirement: compliance_requirement2,
      compliance_requirements_control: control2)
  end

  let_it_be(:project2_control_status) do
    create(:project_control_compliance_status, project: project2, compliance_requirement: compliance_requirement,
      compliance_requirements_control: control1)
  end

  let(:params) { {} }

  subject(:finder) { described_class.new(project, current_user, params) }

  describe '#execute' do
    before_all do
      group.add_owner(current_user)
    end

    context 'when the project is not licensed for the feature' do
      before do
        stub_licensed_features(project_level_compliance_dashboard: false,
          project_level_compliance_adherence_report: false)
      end

      it 'returns empty set of records' do
        expect(finder.execute).to be_empty
      end
    end

    context 'when the project is licensed for the feature' do
      before do
        stub_licensed_features(project_level_compliance_dashboard: true,
          project_level_compliance_adherence_report: true)
      end

      context 'when user is not allowed to view the dashboard' do
        before_all do
          group.add_guest(current_user)
        end

        it 'returns empty set of records' do
          expect(finder.execute).to be_empty
        end
      end

      context 'when user is allowed to view the dashboard' do
        it 'returns control status records for project' do
          expect(finder.execute).to contain_exactly(control_status, another_control_status)
        end

        it 'does not return control status records that do not belong to the project' do
          expect(finder.execute).to exclude(project2_control_status)
        end

        context 'when filtering by compliance requirement ID' do
          let(:params) { { compliance_requirement_id: compliance_requirement.id } }

          it 'returns filtered control status records' do
            records = finder.execute

            expect(records).to contain_exactly(control_status)
          end
        end

        context 'when filtering by non-existent compliance requirement ID' do
          let(:params) { { compliance_requirement_id: non_existing_record_id } }

          it 'returns empty set of records' do
            expect(finder.execute).to be_empty
          end
        end
      end
    end
  end
end
