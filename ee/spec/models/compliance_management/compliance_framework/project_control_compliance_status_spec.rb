# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:compliance_requirements_control) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:compliance_requirement) }
    it { is_expected.to belong_to(:requirement_status) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_requirements_control) }

    describe 'uniqueness validation' do
      subject { build(:project_control_compliance_status) }

      it 'validates uniqueness of project id scoped to control id' do
        create(:project_control_compliance_status)
        is_expected.to validate_uniqueness_of(:project_id)
                         .scoped_to(:compliance_requirements_control_id)
                         .with_message('has already been taken')
      end
    end

    describe 'validating associations' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let_it_be(:project) { create(:project, group: subgroup) }
      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
      let_it_be(:requirement) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: 'requirement1')
      end

      let_it_be(:other_requirement) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: 'requirement2')
      end

      let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

      before_all do
        create(:compliance_framework_project_setting, project: project,
          compliance_management_framework: compliance_framework)
      end

      describe '#control_belongs_to_requirement' do
        context 'when the control belongs to requirement' do
          subject(:build_status) do
            build(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          it 'is valid' do
            expect(build_status).to be_valid
          end
        end

        context 'when the control belongs to a different requirement' do
          subject(:build_status) do
            build(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: other_requirement)
          end

          it 'is invalid' do
            expect(build_status).not_to be_valid
            expect(build_status.errors[:compliance_requirements_control])
              .to include(_('must belong to the compliance requirement.'))
          end
        end

        context 'when record is updated' do
          let_it_be_with_reload(:status) do
            create(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          let_it_be(:project1) { create(:project, group: namespace) }

          before_all do
            create(:compliance_framework_project_setting, project: project1,
              compliance_management_framework: compliance_framework)
          end

          context 'when neither control nor requirement is updated' do
            subject(:update_status) do
              status.update(compliance_requirement: requirement, project: project) # rubocop: disable Rails/SaveBang -- checking value too
            end

            it 'does not compare control and requirement' do
              expect(control).not_to receive(:compliance_requirement_id)

              expect(update_status).to be_truthy

              expect(status).to be_valid
            end
          end

          context 'when control do not match with updated requirement' do
            subject(:update_status) do
              status.update(compliance_requirement: other_requirement) # rubocop: disable Rails/SaveBang -- checking value too
            end

            it 'is invalid' do
              expect(update_status).to be_falsey

              expect(status).not_to be_valid
              expect(status.errors[:compliance_requirements_control])
                .to include(_('must belong to the compliance requirement.'))
            end
          end
        end
      end

      describe '#framework_applied_to_project' do
        let_it_be(:project1) { create(:project, group: namespace) }

        context 'when the framework is applied to the project' do
          subject(:build_status) do
            build(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          it 'is valid' do
            expect(build_status).to be_valid
          end
        end

        context 'when the framework is not applied to the project' do
          subject(:build_status) do
            build(:project_control_compliance_status, project: project1, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          it 'is invalid' do
            expect(build_status).not_to be_valid
            expect(build_status.errors[:project])
              .to include(_("should have the compliance requirement's framework applied to it."))
          end
        end

        context 'when a different framework is applied to the project' do
          let_it_be(:framework2) { create(:compliance_framework, namespace: namespace, name: 'framework2') }

          before do
            create(:compliance_framework_project_setting,
              project: project1,
              compliance_management_framework: framework2)
          end

          subject(:build_status) do
            build(:project_control_compliance_status, project: project1, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          it 'is invalid' do
            expect(build_status).not_to be_valid
            expect(build_status.errors[:project])
              .to include(_("should have the compliance requirement's framework applied to it."))
          end
        end

        context 'when record is updated' do
          let_it_be_with_reload(:status) do
            create(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          context 'when neither project nor requirement is updated' do
            subject(:update_status) do
              status.update(compliance_requirement: requirement, project: project) # rubocop: disable Rails/SaveBang -- checking value too
            end

            it 'does not compare project and requirement' do
              expect(ComplianceManagement::ComplianceFramework::ProjectSettings)
                .not_to receive(:by_framework_and_project)

              expect(update_status).to be_truthy

              expect(status).to be_valid
            end
          end

          context 'when project does not match with updated requirement' do
            let_it_be(:compliance_framework2) do
              create(:compliance_framework, namespace: namespace, name: 'compliance_framework2')
            end

            let_it_be(:requirement2) do
              create(:compliance_requirement, framework: compliance_framework2, namespace: namespace,
                name: 'requirement2')
            end

            subject(:update_status) do
              status.update(compliance_requirement: requirement2) # rubocop: disable Rails/SaveBang -- checking value too
            end

            it 'is invalid' do
              expect(update_status).to be_falsey

              expect(status).not_to be_valid
              expect(status.errors[:project])
                .to include(_("should have the compliance requirement's framework applied to it."))
            end
          end
        end
      end

      describe '#project_belongs_to_same_namespace' do
        context 'when the project belongs to same namespace' do
          subject(:build_status) do
            build(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          it 'is valid' do
            expect(build_status).to be_valid
          end
        end

        context 'when the project belongs to a different namespace' do
          let_it_be(:project2) { create(:project, group: create(:group)) }

          before do
            create(:compliance_framework_project_setting,
              project: project2,
              compliance_management_framework: compliance_framework)
          end

          subject(:build_status) do
            build(:project_control_compliance_status, project: project2, compliance_requirements_control: control,
              compliance_requirement: requirement, namespace: namespace)
          end

          it 'is invalid' do
            expect(build_status).not_to be_valid
            expect(build_status.errors[:project]).to include(_('must belong to the same namespace.'))
          end
        end

        context 'when record is updated' do
          let_it_be_with_reload(:status) do
            create(:project_control_compliance_status, project: project, compliance_requirements_control: control,
              compliance_requirement: requirement)
          end

          context 'when neither project nor namespace is updated' do
            subject(:update_status) do
              status.update(project: project) # rubocop: disable Rails/SaveBang -- checking value too
            end

            it 'does not compare project and namespace' do
              expect(project).not_to receive(:namespace_id)

              expect(update_status).to be_truthy

              expect(status).to be_valid
            end
          end

          context 'when project does not match with updated namespace' do
            subject(:update_status) do
              status.update(namespace: namespace) # rubocop: disable Rails/SaveBang -- checking value too
            end

            it 'is invalid' do
              expect(update_status).to be_falsey

              expect(status).not_to be_valid
              expect(status.errors[:project]).to include(_('must belong to the same namespace.'))
            end
          end
        end
      end
    end

    describe '#validate_requirement_status' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: namespace) }
      let_it_be(:project) { create(:project, group: subgroup) }
      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
      let_it_be(:requirement) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: 'requirement1')
      end

      let_it_be(:other_requirement) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: 'requirement2')
      end

      let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
      let_it_be(:requirement_status1) do
        create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement)
      end

      let_it_be(:requirement_status2) do
        create(:project_requirement_compliance_status, project: project, compliance_requirement: other_requirement)
      end

      let(:control_status) do
        build(:project_control_compliance_status, project: project, compliance_requirements_control: control,
          compliance_requirement: requirement)
      end

      context 'when requirement_status is provided' do
        context 'when requirement_status is of same requirement' do
          it 'is valid' do
            control_status.requirement_status = requirement_status1

            expect(control_status).to be_valid
          end
        end

        context 'when requirement_status is of different requirement' do
          it 'is invalid' do
            control_status.requirement_status = requirement_status2

            expect(control_status).to be_invalid
            expect(control_status.errors[:requirement_status])
              .to include(_("must belong to the same compliance requirement."))
          end
        end
      end

      context 'when requirement_status is nil' do
        before do
          control_status.requirement_status = nil
        end

        it 'is valid' do
          expect(control_status).to be_valid
        end
      end

      context 'when updating an existing record' do
        let!(:existing_status) do
          create(:project_control_compliance_status, project: project, compliance_requirements_control: control,
            compliance_requirement: requirement)
        end

        context 'when requirement_status is of same requirement' do
          it 'is valid' do
            existing_status.requirement_status = requirement_status1

            expect(existing_status).to be_valid
          end
        end

        context 'when requirement_status is of different requirement' do
          it 'is invalid' do
            existing_status.requirement_status = requirement_status2

            expect(existing_status).to be_invalid
            expect(existing_status.errors[:requirement_status])
              .to include(_("must belong to the same compliance requirement."))
          end
        end
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pass: 0, fail: 1, pending: 2) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      status = create(:project_control_compliance_status)
      expect(status).to be_valid
    end
  end

  describe '.for_project_and_control' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) do
      create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: 'requirement1')
    end

    let_it_be(:requirement2) do
      create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: 'requirement2')
    end

    let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }
    let_it_be(:another_control) { create(:compliance_requirements_control, compliance_requirement: requirement2) }
    let_it_be(:another_project) { create(:project, group: namespace) }

    let_it_be_with_reload(:status) do
      create(:project_control_compliance_status,
        project: project,
        compliance_requirements_control: control, compliance_requirement: requirement, namespace: namespace
      )
    end

    let_it_be(:another_project_status) do
      create(:project_control_compliance_status,
        project: another_project,
        compliance_requirements_control: control, compliance_requirement: requirement, namespace: namespace
      )
    end

    let_it_be(:another_control_status) do
      create(:project_control_compliance_status,
        project: project,
        compliance_requirements_control: another_control, compliance_requirement: requirement2, namespace: namespace
      )
    end

    it 'returns records matching project_id and control_id' do
      result = described_class.for_project_and_control(project.id, control.id)

      expect(result).to contain_exactly(status)
    end

    it 'returns empty when no matching records exist' do
      result = described_class.for_project_and_control(non_existing_record_id, non_existing_record_id)

      expect(result).to be_empty
    end

    it 'does not return records for different project' do
      result = described_class.for_project_and_control(another_project.id, control.id)

      expect(result).not_to include(status)
      expect(result).to contain_exactly(another_project_status)
    end
  end

  describe '.create_or_find_for_project_and_control' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: namespace) }
    let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

    context 'when record does not exist' do
      before do
        create(:compliance_framework_project_setting, project: project,
          compliance_management_framework: compliance_framework)
      end

      it 'creates a new record' do
        expect do
          described_class.create_or_find_for_project_and_control(project, control)
        end.to change { described_class.count }.by(1)
      end

      it 'sets correct attributes', :aggregate_failures do
        status = described_class.create_or_find_for_project_and_control(project, control)

        expect(status.project_id).to eq(project.id)
        expect(status.compliance_requirements_control_id).to eq(control.id)
        expect(status.compliance_requirement_id).to eq(control.compliance_requirement_id)
        expect(status.namespace_id).to eq(project.namespace_id)
        expect(status).to be_pending
      end
    end

    context 'when record exists' do
      let_it_be(:existing_status) do
        create(:project_control_compliance_status,
          project: project,
          compliance_requirements_control: control, compliance_requirement: requirement, namespace: namespace)
      end

      it 'returns existing record' do
        status = described_class.create_or_find_for_project_and_control(project, control)

        expect(status).to eq(existing_status)
      end

      it 'does not create a new record' do
        expect do
          described_class.create_or_find_for_project_and_control(project, control)
        end.not_to change { described_class.count }
      end
    end

    context 'when concurrent creation occurs' do
      context "when ActiveRecord::RecordNotUnique is raised" do
        let!(:existing_status) do
          create(:project_control_compliance_status,
            project: project,
            compliance_requirements_control: control, compliance_requirement: requirement, namespace: namespace)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_control)
                                      .with(project.id, control.id)
                                      .and_return(empty_relation, record_relation)

          allow(described_class).to receive(:create!)
                                      .and_raise(ActiveRecord::RecordNotUnique)
        end

        it 'handles race condition and returns existing record' do
          status = described_class.create_or_find_for_project_and_control(project, control)

          expect(status).to eq(existing_status)
        end
      end

      context "when ActiveRecord::RecordInvalid is raised" do
        let!(:existing_status) do
          create(:project_control_compliance_status,
            project: project,
            compliance_requirements_control: control, compliance_requirement: requirement, namespace: namespace)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_control)
                                      .with(project.id, control.id)
                                      .and_return(empty_relation, record_relation)

          allow(described_class).to receive(:create!)
                                      .and_raise(
                                        ActiveRecord::RecordInvalid.new(
                                          existing_status.tap do |status|
                                            status.errors.add(:project_id, :taken, message: "has already been taken")
                                          end
                                        )
                                      )
        end

        it 'handles race condition and returns existing record' do
          status = described_class.create_or_find_for_project_and_control(project, control)

          expect(status).to eq(existing_status)
        end
      end
    end

    context "when ActiveRecord::RecordInvalid isn't cause by project_id" do
      let!(:existing_status) do
        create(:project_control_compliance_status,
          project: project,
          compliance_requirements_control: control, compliance_requirement: requirement, namespace: namespace)
      end

      before do
        empty_relation = described_class.none
        record_relation = described_class.where(id: existing_status.id)

        allow(described_class).to receive(:for_project_and_control)
                                    .with(project.id, control.id)
                                    .and_return(empty_relation, record_relation)

        allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'raises the error' do
        expect do
          described_class.create_or_find_for_project_and_control(project, control)
        end.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    describe '.for_projects' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project1) { create(:project, namespace: namespace) }
      let_it_be(:project2) { create(:project, namespace: namespace) }

      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: namespace) }
      let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

      let_it_be_with_reload(:status1) do
        create(:project_control_compliance_status, project: project1, compliance_requirements_control: control,
          compliance_requirement: requirement)
      end

      let_it_be_with_refind(:status2) do
        create(:project_control_compliance_status, project: project2, compliance_requirements_control: control,
          compliance_requirement: requirement)
      end

      context 'when given a single project ID' do
        it 'returns statuses for the specified project' do
          expect(described_class.for_projects(project1.id)).to contain_exactly(status1)
        end
      end

      context 'when given multiple project IDs' do
        it 'returns statuses for all specified projects' do
          expect(described_class.for_projects([project1.id, project2.id])).to contain_exactly(status1, status2)
        end
      end

      context 'when given an array with a single project ID' do
        it 'returns statuses for the specified project' do
          expect(described_class.for_projects([project1.id])).to contain_exactly(status1)
        end
      end

      context 'when given an empty array' do
        it 'returns an empty relation' do
          expect(described_class.for_projects([])).to be_empty
        end
      end

      context 'when given nil' do
        it 'returns an empty relation' do
          expect(described_class.for_projects(nil)).to be_empty
        end
      end

      context 'when given non-existent project IDs' do
        it 'returns an empty relation' do
          expect(described_class.for_projects(non_existing_record_id)).to be_empty
        end
      end

      context 'when given a mix of existing and non-existent project IDs' do
        it 'returns statuses only for existing projects' do
          expect(described_class.for_projects([project1.id, non_existing_record_id])).to contain_exactly(status1)
        end
      end

      context 'when chained with other scopes' do
        before do
          status1.update!(status: :pass)
          status2.update!(status: :fail)
        end

        it 'works correctly with other scopes' do
          result = described_class.for_projects([project1.id, project2.id]).where(status: :pass)
          expect(result).to contain_exactly(status1)
        end
      end
    end

    describe '.for_requirements' do
      let_it_be(:namespace) { create(:group) }
      let_it_be(:project) { create(:project, namespace: namespace) }
      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
      let_it_be(:requirement1) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace)
      end

      let_it_be(:requirement2) do
        create(:compliance_requirement, framework: compliance_framework, namespace: namespace)
      end

      let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement1) }
      let_it_be(:control2) { create(:compliance_requirements_control, compliance_requirement: requirement2) }

      let_it_be_with_reload(:status1) do
        create(:project_control_compliance_status, project: project, compliance_requirements_control: control1,
          compliance_requirement: requirement1)
      end

      let_it_be_with_refind(:status2) do
        create(:project_control_compliance_status, project: project, compliance_requirements_control: control2,
          compliance_requirement: requirement2)
      end

      context 'when given a single requirement ID' do
        it 'returns statuses for the specified requirement' do
          expect(described_class.for_requirements(requirement1.id)).to contain_exactly(status1)
        end
      end

      context 'when given multiple requirement IDs' do
        it 'returns statuses for all specified requirements' do
          expect(described_class.for_requirements([requirement1.id,
            requirement2.id])).to contain_exactly(status1, status2)
        end
      end

      context 'when given an array with a single requirement ID' do
        it 'returns statuses for the specified requirement' do
          expect(described_class.for_requirements([requirement1.id])).to contain_exactly(status1)
        end
      end

      context 'when given an empty array' do
        it 'returns an empty relation' do
          expect(described_class.for_requirements([])).to be_empty
        end
      end

      context 'when given nil' do
        it 'returns an empty relation' do
          expect(described_class.for_requirements(nil)).to be_empty
        end
      end

      context 'when given non-existent requirement IDs' do
        it 'returns an empty relation' do
          expect(described_class.for_requirements(non_existing_record_id)).to be_empty
        end
      end

      context 'when given a mix of existing and non-existent requirement IDs' do
        it 'returns statuses only for existing requirements' do
          expect(described_class.for_requirements([requirement1.id,
            non_existing_record_id])).to contain_exactly(status1)
        end
      end

      context 'when chained with other scopes' do
        before do
          status1.update!(status: :pass)
          status2.update!(status: :fail)
        end

        it 'works correctly with other scopes' do
          result = described_class.for_requirements([requirement1.id, requirement2.id]).where(status: :pass)
          expect(result).to contain_exactly(status1)
        end
      end
    end
  end

  describe '.control_coverage_statistics' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project1) { create(:project, namespace: namespace) }
    let_it_be(:project2) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: namespace) }
    let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
    let_it_be(:control2) { create(:compliance_requirements_control, :external, compliance_requirement: requirement) }

    context 'when there are no control statuses' do
      it 'returns an empty hash' do
        result = described_class.control_coverage_statistics([project1.id, project2.id])

        expect(result).to eq({})
      end
    end

    context 'when there are control statuses' do
      let_it_be(:pass_status1) do
        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control1,
          compliance_requirement: requirement,
          status: :pass
        )
      end

      let_it_be(:fail_status) do
        create(:project_control_compliance_status,
          project: project1,
          compliance_requirements_control: control2,
          compliance_requirement: requirement,
          status: :fail
        )
      end

      let_it_be(:pending_status) do
        create(:project_control_compliance_status,
          project: project2,
          compliance_requirements_control: control1,
          compliance_requirement: requirement,
          status: :pending
        )
      end

      let_it_be(:pass_status2) do
        create(:project_control_compliance_status,
          project: project2,
          compliance_requirements_control: control2,
          compliance_requirement: requirement,
          status: :pass
        )
      end

      it 'returns correct counts grouped by status' do
        result = described_class.control_coverage_statistics([project1.id, project2.id])

        expect(result).to eq({
          'pass' => 2,
          'fail' => 1,
          'pending' => 1
        })
      end

      it 'only includes statuses for specified projects' do
        result = described_class.control_coverage_statistics([project1.id])

        expect(result).to eq({
          'pass' => 1,
          'fail' => 1
        })
      end

      it 'returns empty hash when given non-existent project ids' do
        result = described_class.control_coverage_statistics([non_existing_record_id])

        expect(result).to eq({})
      end
    end
  end
end
