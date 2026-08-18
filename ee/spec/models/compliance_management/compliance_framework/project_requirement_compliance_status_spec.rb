# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectRequirementComplianceStatus,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:compliance_framework) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:compliance_requirement) }

    it { is_expected.to have_many(:control_statuses) }
  end

  describe 'validations' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    it { is_expected.to validate_presence_of(:pass_count) }
    it { is_expected.to validate_presence_of(:fail_count) }
    it { is_expected.to validate_presence_of(:pending_count) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_framework) }

    it { is_expected.to validate_numericality_of(:pass_count).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:fail_count).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:pending_count).only_integer.is_greater_than_or_equal_to(0) }

    describe 'uniqueness validation' do
      subject { build(:project_requirement_compliance_status) }

      it 'validates uniqueness of project id scoped to requirement id' do
        create(:project_requirement_compliance_status)
        is_expected.to validate_uniqueness_of(:project_id)
                         .scoped_to(:compliance_requirement_id)
                         .with_message('has already been taken')
      end
    end

    describe '#framework_applied_to_project' do
      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: group) }

      context 'when the framework is applied to the project' do
        before do
          create(:compliance_framework_project_setting, project: project,
            compliance_management_framework: compliance_framework)
        end

        subject(:build_status) do
          build(:project_requirement_compliance_status, project: project, compliance_requirement: requirement,
            namespace: group, compliance_framework: compliance_framework)
        end

        it 'is valid' do
          expect(build_status).to be_valid
        end
      end

      context 'when the framework is not applied to the project' do
        subject(:build_status) do
          build(:project_requirement_compliance_status, project: project, compliance_requirement: requirement,
            namespace: group, compliance_framework: compliance_framework)
        end

        it 'is invalid' do
          expect(build_status).not_to be_valid
          expect(build_status.errors[:compliance_framework]).to include('must be applied to the project.')
        end
      end
    end

    describe '#project_belongs_to_same_namespace' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: group) }

      before do
        create(:compliance_framework_project_setting, project: project,
          compliance_management_framework: compliance_framework)
      end

      context 'when the project belongs to the same namespace' do
        subject(:build_status) do
          build(:project_requirement_compliance_status, project: project, compliance_requirement: requirement,
            namespace: group, compliance_framework: compliance_framework)
        end

        it 'is valid' do
          expect(build_status).to be_valid
        end
      end

      context 'when the project belongs to a different namespace' do
        subject(:build_status) do
          build(:project_requirement_compliance_status, project: other_project, compliance_requirement: requirement,
            namespace: group, compliance_framework: compliance_framework)
        end

        it 'is invalid' do
          expect(build_status).not_to be_valid
          expect(build_status.errors[:project]).to include('must belong to the same namespace.')
        end
      end
    end

    describe '#requirement_belongs_to_framework' do
      let_it_be(:compliance_framework1) do
        create(:compliance_framework, namespace: group, name: 'framework1', color: '#00ffaa')
      end

      let_it_be(:compliance_framework2) do
        create(:compliance_framework, namespace: group, name: 'framework2', color: '#00ffab')
      end

      let_it_be(:requirement1) { create(:compliance_requirement, framework: compliance_framework1, namespace: group) }
      let_it_be(:requirement2) { create(:compliance_requirement, framework: compliance_framework2, namespace: group) }

      before do
        create(:compliance_framework_project_setting, project: project,
          compliance_management_framework: compliance_framework1)
      end

      context 'when the requirement belongs to the same framework as the status' do
        subject(:build_status) do
          build(:project_requirement_compliance_status, project: project, compliance_framework: compliance_framework1,
            compliance_requirement: requirement1, namespace: group)
        end

        it 'is valid' do
          expect(build_status).to be_valid
        end
      end

      context 'when the requirement does not belong to the same framework as the status' do
        subject(:build_status) do
          build(:project_requirement_compliance_status, project: project, compliance_framework: compliance_framework1,
            compliance_requirement: requirement2, namespace: group)
        end

        it 'is invalid' do
          expect(build_status).not_to be_valid
          expect(build_status.errors[:compliance_requirement])
            .to include('must belong to the same compliance framework.')
        end
      end
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      status = create(:project_requirement_compliance_status)
      expect(status).to be_valid
    end
  end

  describe '.order_by_updated_at_and_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement1) { create(:compliance_requirement, namespace: group, framework: framework) }
    let_it_be(:requirement2) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement2')
    end

    let_it_be(:requirement3) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement3')
    end

    let_it_be(:project) { create(:project, namespace: group) }

    let_it_be(:requirement_status1) do
      create(:project_requirement_compliance_status, compliance_requirement: requirement1, project: project,
        updated_at: 1.day.ago)
    end

    let_it_be(:requirement_status2) do
      create(:project_requirement_compliance_status, compliance_requirement: requirement2, project: project,
        updated_at: 1.week.ago)
    end

    let_it_be(:requirement_status3) do
      create(:project_requirement_compliance_status, compliance_requirement: requirement3, project: project,
        updated_at: 2.days.ago)
    end

    context 'when direction is not provided' do
      it 'sorts by updated_at in ascending order by default' do
        expect(described_class.order_by_updated_at_and_id).to eq(
          [
            requirement_status2,
            requirement_status3,
            requirement_status1
          ]
        )
      end
    end

    context 'when direction is asc' do
      it 'sorts by updated_at in ascending order by default' do
        expect(described_class.order_by_updated_at_and_id(:asc)).to eq(
          [
            requirement_status2,
            requirement_status3,
            requirement_status1
          ]
        )
      end
    end

    context 'when direction is desc' do
      it 'sorts in descending order' do
        expect(described_class.order_by_updated_at_and_id(:desc)).to eq(
          [
            requirement_status1,
            requirement_status3,
            requirement_status2
          ]
        )
      end
    end

    context 'when direction is invalid' do
      it 'raises error' do
        expect do
          described_class.order_by_updated_at_and_id(:invalid)
        end.to raise_error(ArgumentError, /Direction "invalid" is invalid/)
      end
    end
  end

  describe '.order_by_project_and_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement) { create(:compliance_requirement, namespace: group, framework: framework) }

    let_it_be(:project1) { create(:project, namespace: group, path: 'project1') }
    let_it_be(:project2) { create(:project, namespace: group, path: 'project2') }
    let_it_be(:project3) { create(:project, namespace: group, path: 'project3') }

    let_it_be(:requirement_status1) do
      create(:project_requirement_compliance_status, project: project2, compliance_requirement: requirement)
    end

    let_it_be(:requirement_status2) do
      create(:project_requirement_compliance_status, project: project3, compliance_requirement: requirement)
    end

    let_it_be(:requirement_status3) do
      create(:project_requirement_compliance_status, project: project1, compliance_requirement: requirement)
    end

    context 'when direction is not provided' do
      it 'sorts by project_id in ascending order by default' do
        expect(described_class.order_by_project_and_id).to eq(
          [
            requirement_status3, # project1
            requirement_status1, # project2
            requirement_status2  # project3
          ]
        )
      end
    end

    context 'when direction is asc' do
      it 'sorts by project_id in ascending order' do
        expect(described_class.order_by_project_and_id(:asc)).to eq(
          [
            requirement_status3, # project1
            requirement_status1, # project2
            requirement_status2  # project3
          ]
        )
      end
    end

    context 'when direction is desc' do
      it 'sorts in descending order' do
        expect(described_class.order_by_project_and_id(:desc)).to eq(
          [
            requirement_status2, # project3
            requirement_status1, # project2
            requirement_status3  # project1
          ]
        )
      end
    end

    context 'when direction is invalid' do
      it 'raises error' do
        expect do
          described_class.order_by_project_and_id(:invalid)
        end.to raise_error(ArgumentError, /Direction "invalid" is invalid/)
      end
    end
  end

  describe '.order_by_requirement_and_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:project) { create(:project, namespace: group) }

    let_it_be(:requirement1) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement1')
    end

    let_it_be(:requirement2) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement2')
    end

    let_it_be(:requirement3) do
      create(:compliance_requirement, namespace: group, framework: framework, name: 'requirement3')
    end

    let_it_be(:requirement_status1) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement2)
    end

    let_it_be(:requirement_status2) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement3)
    end

    let_it_be(:requirement_status3) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement1)
    end

    context 'when direction is not provided' do
      it 'sorts by compliance_requirement_id in ascending order by default' do
        expect(described_class.order_by_requirement_and_id).to eq(
          [
            requirement_status3, # requirement1
            requirement_status1, # requirement2
            requirement_status2  # requirement3
          ]
        )
      end
    end

    context 'when direction is asc' do
      it 'sorts by compliance_requirement_id in ascending order' do
        expect(described_class.order_by_requirement_and_id(:asc)).to eq(
          [
            requirement_status3, # requirement1
            requirement_status1, # requirement2
            requirement_status2  # requirement3
          ]
        )
      end
    end

    context 'when direction is desc' do
      it 'sorts in descending order' do
        expect(described_class.order_by_requirement_and_id(:desc)).to eq(
          [
            requirement_status2, # requirement3
            requirement_status1, # requirement2
            requirement_status3  # requirement1
          ]
        )
      end
    end

    context 'when direction is invalid' do
      it 'raises error' do
        expect do
          described_class.order_by_requirement_and_id(:invalid)
        end.to raise_error(ArgumentError, /Direction "invalid" is invalid/)
      end
    end
  end

  describe '.order_by_framework_and_id' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }

    let_it_be(:framework1) do
      create(:compliance_framework, namespace: group, name: 'framework1', color: '#00ffaa')
    end

    let_it_be(:framework2) do
      create(:compliance_framework, namespace: group, name: 'framework2', color: '#00ffab')
    end

    let_it_be(:framework3) do
      create(:compliance_framework, namespace: group, name: 'framework3', color: '#00ffac')
    end

    let_it_be(:requirement1) { create(:compliance_requirement, framework: framework2, namespace: group) }
    let_it_be(:requirement2) { create(:compliance_requirement, framework: framework3, namespace: group) }
    let_it_be(:requirement3) { create(:compliance_requirement, framework: framework1, namespace: group) }

    let_it_be(:requirement_status1) do
      create(:project_requirement_compliance_status,
        project: project,
        compliance_requirement: requirement1,
        compliance_framework: framework2
      )
    end

    let_it_be(:requirement_status2) do
      create(:project_requirement_compliance_status,
        project: project,
        compliance_requirement: requirement2,
        compliance_framework: framework3
      )
    end

    let_it_be(:requirement_status3) do
      create(:project_requirement_compliance_status,
        project: project,
        compliance_requirement: requirement3,
        compliance_framework: framework1
      )
    end

    context 'when direction is not provided' do
      it 'sorts by compliance_framework_id in ascending order by default' do
        expect(described_class.order_by_framework_and_id).to eq(
          [
            requirement_status3, # framework1
            requirement_status1, # framework2
            requirement_status2  # framework3
          ]
        )
      end
    end

    context 'when direction is asc' do
      it 'sorts by compliance_framework_id in ascending order' do
        expect(described_class.order_by_framework_and_id(:asc)).to eq(
          [
            requirement_status3, # framework1
            requirement_status1, # framework2
            requirement_status2  # framework3
          ]
        )
      end
    end

    context 'when direction is desc' do
      it 'sorts in descending order' do
        expect(described_class.order_by_framework_and_id(:desc)).to eq(
          [
            requirement_status2, # framework3
            requirement_status1, # framework2
            requirement_status3  # framework1
          ]
        )
      end
    end

    context 'when direction is invalid' do
      it 'raises error' do
        expect do
          described_class.order_by_framework_and_id(:invalid)
        end.to raise_error(ArgumentError, /Direction "invalid" is invalid/)
      end
    end
  end

  describe '.delete_all_project_statuses' do
    context 'when project has associated compliance requirement statuses' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:project2) { create(:project, group: group) }
      let_it_be(:framework) { create(:compliance_framework, namespace: group) }

      before do
        create(:project_requirement_compliance_status, project: project,
          compliance_requirement: create(:compliance_requirement, namespace: group, framework: framework,
            name: 'requirement1')
        )
        create(:project_requirement_compliance_status, project: project,
          compliance_requirement: create(:compliance_requirement, namespace: group, framework: framework,
            name: 'requirement2')
        )

        create(:project_requirement_compliance_status, project: project2,
          compliance_requirement: create(:compliance_requirement, namespace: group, framework: framework,
            name: 'requirement3')
        )
      end

      it 'destroys all records associated with the project' do
        expect do
          described_class.delete_all_project_statuses(project.id)
        end.to change { described_class.where(project_id: project.id).count }.from(2).to(0)
      end

      it 'does not destroy records associated with other projects' do
        expect do
          described_class.delete_all_project_statuses(project.id)
        end.not_to change { described_class.where(project_id: project2.id).count }
      end
    end
  end

  describe '.for_projects' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project1) { create(:project, namespace: namespace) }
    let_it_be(:project2) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: namespace) }

    let_it_be_with_reload(:status1) do
      create(:project_requirement_compliance_status, project: project1, compliance_requirement: requirement)
    end

    let_it_be_with_reload(:status2) do
      create(:project_requirement_compliance_status, project: project2, compliance_requirement: requirement)
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
        status1.update!(pass_count: 5)
        status2.update!(pass_count: 10)
      end

      it 'works correctly with other scopes' do
        result = described_class.for_projects([project1.id, project2.id]).where('pass_count > ?', 7)
        expect(result).to contain_exactly(status2)
      end
    end
  end

  describe '.for_requirements' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement1) do
      create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: "requirement1")
    end

    let_it_be(:requirement2) do
      create(:compliance_requirement, framework: compliance_framework, namespace: namespace, name: "requirement2")
    end

    let_it_be_with_reload(:status1) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement1)
    end

    let_it_be_with_reload(:status2) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement2)
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
        expect(described_class.for_requirements([requirement1.id, non_existing_record_id])).to contain_exactly(status1)
      end
    end

    context 'when chained with other scopes' do
      before do
        status1.update!(pass_count: 5)
        status2.update!(pass_count: 10)
      end

      it 'works correctly with other scopes' do
        result = described_class.for_requirements([requirement1.id, requirement2.id]).where('pass_count > ?', 7)
        expect(result).to contain_exactly(status2)
      end
    end
  end

  describe '.for_frameworks' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:framework1) { create(:compliance_framework, namespace: namespace, name: 'framework1', color: '#00ffaa') }
    let_it_be(:framework2) { create(:compliance_framework, namespace: namespace, name: 'framework2', color: '#00ffab') }

    let_it_be(:requirement1) { create(:compliance_requirement, framework: framework1, namespace: namespace) }
    let_it_be(:requirement2) { create(:compliance_requirement, framework: framework2, namespace: namespace) }

    let_it_be_with_reload(:status1) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement1,
        compliance_framework: framework1)
    end

    let_it_be_with_reload(:status2) do
      create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement2,
        compliance_framework: framework2)
    end

    context 'when given a single framework ID' do
      it 'returns statuses for the specified framework' do
        expect(described_class.for_frameworks(framework1.id)).to contain_exactly(status1)
      end
    end

    context 'when given multiple framework IDs' do
      it 'returns statuses for all specified frameworks' do
        expect(described_class.for_frameworks([framework1.id, framework2.id])).to contain_exactly(status1, status2)
      end
    end

    context 'when given an array with a single framework ID' do
      it 'returns statuses for the specified framework' do
        expect(described_class.for_frameworks([framework1.id])).to contain_exactly(status1)
      end
    end

    context 'when given an empty array' do
      it 'returns an empty relation' do
        expect(described_class.for_frameworks([])).to be_empty
      end
    end

    context 'when given nil' do
      it 'returns an empty relation' do
        expect(described_class.for_frameworks(nil)).to be_empty
      end
    end

    context 'when given non-existent framework IDs' do
      it 'returns an empty relation' do
        expect(described_class.for_frameworks(non_existing_record_id)).to be_empty
      end
    end

    context 'when given a mix of existing and non-existent framework IDs' do
      it 'returns statuses only for existing frameworks' do
        expect(described_class.for_frameworks([framework1.id, non_existing_record_id])).to contain_exactly(status1)
      end
    end

    context 'when chained with other scopes' do
      before do
        status1.update!(pass_count: 5)
        status2.update!(pass_count: 10)
      end

      it 'works correctly with other scopes' do
        result = described_class.for_frameworks([framework1.id, framework2.id]).where('pass_count > ?', 7)
        expect(result).to contain_exactly(status2)
      end
    end
  end

  describe '.for_project_and_requirement' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project1) { create(:project, namespace: namespace) }
    let_it_be(:project2) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement1) { create(:compliance_requirement, framework: compliance_framework) }
    let_it_be(:requirement2) { create(:compliance_requirement, framework: compliance_framework) }

    let_it_be_with_reload(:status1) do
      create(:project_requirement_compliance_status, project: project1, compliance_requirement: requirement1)
    end

    let_it_be_with_reload(:status2) do
      create(:project_requirement_compliance_status, project: project2, compliance_requirement: requirement2)
    end

    context 'when a matching status exists' do
      it 'returns the status for the specified project and requirement' do
        result = described_class.for_project_and_requirement(project1.id, requirement1.id)
        expect(result).to contain_exactly(status1)
      end
    end

    context 'when no matching status exists' do
      it 'returns nil for a non-existent project' do
        result = described_class.for_project_and_requirement(non_existing_record_id, requirement1.id)
        expect(result).to be_empty
      end

      it 'returns empty for a non-existent requirement' do
        result = described_class.for_project_and_requirement(project1.id, non_existing_record_id)
        expect(result).to be_empty
      end

      it 'returns empty for not matching project and requirement' do
        result = described_class.for_project_and_requirement(project1.id, requirement2.id)
        expect(result).to be_empty
      end

      it 'returns empty for a valid project and requirement with no status' do
        project3 = create(:project, namespace: namespace)
        result = described_class.for_project_and_requirement(project3.id, requirement1.id)
        expect(result).to be_empty
      end
    end
  end

  describe '.find_or_create_project_and_requirement' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }

    before_all do
      create(:compliance_framework_project_setting, project: project,
        compliance_management_framework: compliance_framework)
    end

    context 'when record does not exist' do
      it 'creates a new record' do
        expect do
          described_class.find_or_create_project_and_requirement(project, requirement)
        end.to change { described_class.count }.by(1)
      end

      it 'sets correct attributes', :aggregate_failures do
        status = described_class.find_or_create_project_and_requirement(project, requirement)

        expect(status.project_id).to eq(project.id)
        expect(status.compliance_requirement_id).to eq(requirement.id)
        expect(status.compliance_framework_id).to eq(compliance_framework.id)
        expect(status.namespace_id).to eq(namespace.id)
        expect(status.pass_count).to eq(0)
        expect(status.fail_count).to eq(0)
        expect(status.pending_count).to eq(0)
      end
    end

    context 'when record exists' do
      let_it_be(:existing_status) do
        create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement)
      end

      it 'returns existing record' do
        status = described_class.find_or_create_project_and_requirement(project, requirement)

        expect(status).to eq(existing_status)
      end

      it 'does not create a new record' do
        expect do
          described_class.find_or_create_project_and_requirement(project, requirement)
        end.not_to change { described_class.count }
      end
    end

    context 'when concurrent creation occurs' do
      context "when ActiveRecord::RecordNotUnique is raised" do
        let!(:existing_status) do
          create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_requirement)
                                      .with(project.id, requirement.id)
                                      .and_return(empty_relation, record_relation)

          allow(described_class).to receive(:create!)
                                      .and_raise(ActiveRecord::RecordNotUnique)
        end

        it 'handles race condition and returns existing record' do
          status = described_class.find_or_create_project_and_requirement(project, requirement)

          expect(status).to eq(existing_status)
        end
      end

      context "when ActiveRecord::RecordInvalid is raised" do
        let!(:existing_status) do
          create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_requirement)
                                      .with(project.id, requirement.id)
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
          status = described_class.find_or_create_project_and_requirement(project, requirement)

          expect(status).to eq(existing_status)
        end
      end

      context "when ActiveRecord::RecordInvalid isn't cause by project_id" do
        let!(:existing_status) do
          create(:project_requirement_compliance_status, project: project, compliance_requirement: requirement)
        end

        before do
          empty_relation = described_class.none
          record_relation = described_class.where(id: existing_status.id)

          allow(described_class).to receive(:for_project_and_requirement)
                                      .with(project.id, requirement.id)
                                      .and_return(empty_relation, record_relation)

          allow(described_class).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
        end

        it 'raises the error' do
          expect do
            described_class.find_or_create_project_and_requirement(project, requirement)
          end.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end
  end

  describe '#control_status_values' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }

    let_it_be(:requirement_status) do
      create(:project_requirement_compliance_status,
        project: project,
        compliance_requirement: requirement,
        compliance_framework: compliance_framework,
        namespace: namespace
      )
    end

    let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
    let_it_be(:control2) { create(:compliance_requirements_control, :external, compliance_requirement: requirement) }
    let_it_be(:control3) do
      create(:compliance_requirements_control, :project_visibility_not_internal, compliance_requirement: requirement)
    end

    context 'when there are no control statuses' do
      it 'returns an empty array' do
        expect(requirement_status.control_status_values).to be_empty
      end
    end

    context 'when there are control statuses' do
      before do
        create(:project_control_compliance_status, status: 'pass',
          compliance_requirements_control: control1, compliance_requirement: requirement, project: project)
        create(:project_control_compliance_status, status: 'fail',
          compliance_requirements_control: control2, compliance_requirement: requirement, project: project)
        create(:project_control_compliance_status, status: 'pending',
          compliance_requirements_control: control3, compliance_requirement: requirement, project: project)
      end

      it 'returns all status values' do
        expect(requirement_status.control_status_values).to contain_exactly('pass', 'fail', 'pending')
      end
    end

    context 'when control statuses have duplicate status values' do
      before do
        create(:project_control_compliance_status, status: 'pass',
          compliance_requirements_control: control1, compliance_requirement: requirement, project: project)
        create(:project_control_compliance_status, status: 'pass',
          compliance_requirements_control: control2, compliance_requirement: requirement, project: project)
        create(:project_control_compliance_status, status: 'fail',
          compliance_requirements_control: control3, compliance_requirement: requirement, project: project)
      end

      it 'includes duplicate values' do
        statuses = requirement_status.control_status_values

        expect(statuses.count).to eq(3)
        expect(statuses.count('pass')).to eq(2)
        expect(statuses.count('fail')).to eq(1)
      end
    end
  end

  describe '#control_statuses' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project) { create(:project, namespace: namespace) }
    let_it_be(:project2) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }
    let_it_be(:requirement2) { create(:compliance_requirement, framework: compliance_framework) }

    let_it_be(:requirement_status) do
      create(:project_requirement_compliance_status,
        project: project,
        compliance_requirement: requirement,
        compliance_framework: compliance_framework,
        namespace: namespace
      )
    end

    let_it_be(:requirement_status2) do
      create(:project_requirement_compliance_status,
        project: project2,
        compliance_requirement: requirement,
        compliance_framework: compliance_framework,
        namespace: namespace
      )
    end

    let_it_be(:requirement_status3) do
      create(:project_requirement_compliance_status,
        project: project,
        compliance_requirement: requirement2,
        compliance_framework: compliance_framework,
        namespace: namespace
      )
    end

    let_it_be(:control1) { create(:compliance_requirements_control, compliance_requirement: requirement) }
    let_it_be(:control2) { create(:compliance_requirements_control, :external, compliance_requirement: requirement) }
    let_it_be(:control3) do
      create(:compliance_requirements_control, :project_visibility_not_internal, compliance_requirement: requirement)
    end

    let_it_be(:control4) { create(:compliance_requirements_control, compliance_requirement: requirement2) }

    context 'when there are no control statuses' do
      it 'returns an empty array' do
        expect(requirement_status.control_statuses).to be_empty
      end
    end

    context 'when there are control statuses' do
      let_it_be(:control_status1) do
        create(:project_control_compliance_status, status: 'pass',
          compliance_requirements_control: control1, compliance_requirement: requirement, project: project)
      end

      let_it_be(:control_status2) do
        create(:project_control_compliance_status, status: 'fail',
          compliance_requirements_control: control2, compliance_requirement: requirement, project: project)
      end

      let_it_be(:control_status3) do
        create(:project_control_compliance_status, status: 'pending',
          compliance_requirements_control: control3, compliance_requirement: requirement, project: project)
      end

      let_it_be(:control_status4) do
        create(:project_control_compliance_status, status: 'pending',
          compliance_requirements_control: control4, compliance_requirement: requirement2, project: project)
      end

      let_it_be(:project2_control_status) do
        create(:project_control_compliance_status, status: 'pending',
          compliance_requirements_control: control1, compliance_requirement: requirement, project: project2)
      end

      it 'returns all status values' do
        expect(requirement_status.control_statuses).to contain_exactly(control_status1, control_status2,
          control_status3)
      end
    end
  end

  describe '.coverage_statistics' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project1) { create(:project, namespace: namespace) }
    let_it_be(:project2) { create(:project, namespace: namespace) }
    let_it_be(:project3) { create(:project, namespace: namespace) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: namespace, name: "framework 1") }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework, namespace: namespace) }

    context 'when project_ids is empty' do
      it 'returns zeros for all counts' do
        result = described_class.coverage_statistics([])

        expect(result).to eq({ passed: 0, failed: 0, pending: 0 })
      end
    end

    context 'when there are requirement statuses' do
      let_it_be(:passing_status) do
        create(:project_requirement_compliance_status,
          project: project1,
          compliance_requirement: requirement,
          pass_count: 5,
          fail_count: 0,
          pending_count: 0
        )
      end

      let_it_be(:failing_status) do
        create(:project_requirement_compliance_status,
          project: project2,
          compliance_requirement: requirement,
          pass_count: 3,
          fail_count: 2,
          pending_count: 0
        )
      end

      let_it_be(:pending_status) do
        create(:project_requirement_compliance_status,
          project: project3,
          compliance_requirement: requirement,
          pass_count: 2,
          fail_count: 0,
          pending_count: 3
        )
      end

      it 'returns correct counts for specified projects' do
        result = described_class.coverage_statistics([project1.id, project2.id, project3.id])

        expect(result).to eq({
          passed: 1,
          failed: 1,
          pending: 1
        })
      end

      it 'only counts statuses for specified project_ids' do
        result = described_class.coverage_statistics([project1.id])

        expect(result).to eq({ passed: 1, failed: 0, pending: 0 })
      end
    end
  end
end
