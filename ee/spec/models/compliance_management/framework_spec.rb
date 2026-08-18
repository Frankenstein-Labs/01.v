# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Framework, :models, feature_category: :compliance_management do
  using RSpec::Parameterized::TableSyntax

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:projects).through(:project_settings) }

    it do
      is_expected.to have_many(:project_settings)
        .class_name('ComplianceManagement::ComplianceFramework::ProjectSettings')
    end

    it do
      is_expected.to have_many(:compliance_framework_security_policies)
          .class_name('ComplianceManagement::ComplianceFramework::SecurityPolicy')
    end

    it do
      is_expected.to have_many(:security_orchestration_policy_configurations)
        .class_name('Security::OrchestrationPolicyConfiguration').through(:compliance_framework_security_policies)
    end

    it do
      is_expected.to have_many(:compliance_requirements)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirement')
    end

    it do
      is_expected.to have_many(:security_policies)
        .class_name('Security::Policy')
        .through(:compliance_framework_security_policies)
    end
  end

  describe 'validations' do
    let_it_be(:framework, freeze: false) { create(:compliance_framework) }

    subject { framework }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to validate_length_of(:color).is_at_most(10) }
    it { is_expected.to validate_length_of(:pipeline_configuration_full_path).is_at_most(255) }
    it { is_expected.to validate_length_of(:template_id).is_at_most(255) }

    describe 'namespace_is_root_level_group' do
      context 'when namespace is a root group' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is valid' do
          expect(framework).to be_valid
        end
      end

      context 'when namespace is a user namespace' do
        let_it_be(:namespace) { create(:user_namespace) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is invalid' do
          expect(framework).not_to be_valid
          expect(framework.errors[:namespace]).to include('must be a group, user namespaces are not supported.')
        end
      end

      context 'when namespace is a subgroup' do
        let_it_be(:namespace) { create(:group, :nested) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is invalid' do
          expect(framework).not_to be_valid
          expect(framework.errors[:namespace]).to include('must be a root group.')
        end
      end
    end
  end

  describe '#security_orchestration_policy_configurations' do
    let_it_be(:framework, freeze: false) { create(:compliance_framework) }

    context 'when the framework has many same policy configuration with different index' do
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

      let_it_be(:compliance_framework_security_policy1) do
        create(:compliance_framework_security_policy, framework: framework,
          policy_configuration: policy_configuration, policy_index: 0)
      end

      let_it_be(:compliance_framework_security_policy2) do
        create(:compliance_framework_security_policy, framework: framework,
          policy_configuration: policy_configuration, policy_index: 1)
      end

      it 'returns distinct policy configurations' do
        expect(framework.security_orchestration_policy_configurations).to match_array([policy_configuration])
      end
    end
  end

  describe '#linked_to_security_policy?' do
    let_it_be(:framework, freeze: false) { create(:compliance_framework) }

    context 'when the framework is referenced by a security policy' do
      before do
        create(:compliance_framework_security_policy, framework: framework)
      end

      it 'returns true' do
        expect(framework.linked_to_security_policy?).to be(true)
      end
    end

    context 'when the framework is not referenced by a security policy' do
      it 'returns false' do
        expect(framework.linked_to_security_policy?).to be(false)
      end
    end
  end

  describe 'color' do
    context 'with whitespace' do
      subject { create(:compliance_framework, color: ' #ABC123 ') }

      it 'strips whitespace' do
        expect(subject.color).to eq('#ABC123')
      end
    end
  end

  describe '.search' do
    let_it_be(:framework, freeze: false) { create(:compliance_framework, name: 'some framework name') }
    let_it_be(:framework2) { create(:compliance_framework, name: 'another framework') }

    it 'returns frameworks with a matching name' do
      expect(described_class.search(framework.name)).to eq([framework])
    end

    it 'returns frameworks with a partially matching name' do
      expect(described_class.search(framework.name[0..2])).to eq([framework])
    end

    it 'returns frameworks with a matching name regardless of the casing' do
      expect(described_class.search(framework.name.upcase)).to eq([framework])
    end

    it 'returns multiple frameworks matching with name' do
      expect(described_class.search('rame')).to match_array([framework, framework2])
    end

    it 'returns all frameworks if search string is empty' do
      expect(described_class.search('')).to match_array([framework, framework2])
    end
  end

  describe '.sort_by_attribute' do
    let_it_be(:framework_1) { create(:compliance_framework, name: 'Framework A', updated_at: 1.day.ago) }
    let_it_be(:framework_2) { create(:compliance_framework, name: 'Framework B', updated_at: 5.days.ago) }

    where(:sort_method, :expected_order) do
      nil              | ['Framework A', 'Framework B']
      :non_existent    | ['Framework A', 'Framework B']
      :name_asc        | ['Framework A', 'Framework B']
      :name_desc       | ['Framework B', 'Framework A']
      :updated_at_asc  | ['Framework B', 'Framework A']
      :updated_at_desc | ['Framework A', 'Framework B']
    end

    with_them do
      it "sorts frameworks correctly" do
        framework_names = described_class.sort_by_attribute(sort_method).pluck(:name)

        expect(framework_names).to eq(expected_order)
      end
    end
  end

  describe '#approval_settings_from_security_policies' do
    let_it_be(:framework, freeze: false) { create(:compliance_framework) }
    let_it_be(:policy_configuration1) { create(:security_orchestration_policy_configuration) }
    let_it_be(:policy_configuration2) { create(:security_orchestration_policy_configuration) }
    let_it_be(:project1) { create(:project) }
    let_it_be(:project2) { create(:project) }

    let_it_be(:policy1) do
      create(:compliance_framework_security_policy,
        framework: framework,
        policy_configuration: policy_configuration1,
        policy_index: 0)
    end

    let_it_be(:policy2) do
      create(:compliance_framework_security_policy,
        framework: framework,
        policy_configuration: policy_configuration2,
        policy_index: 0)
    end

    let_it_be(:scan_policy_read1) do
      create(:scan_result_policy_read, :prevent_approval_by_author,
        security_orchestration_policy_configuration: policy_configuration1,
        project: project1)
    end

    let_it_be(:scan_policy_read2) do
      create(:scan_result_policy_read, :prevent_approval_by_commit_author,
        security_orchestration_policy_configuration: policy_configuration1,
        project: project2)
    end

    let_it_be(:scan_policy_read3) do
      create(:scan_result_policy_read, :blocking_protected_branches,
        security_orchestration_policy_configuration: policy_configuration2,
        project: project1)
    end

    context 'when framework has multiple policy configurations with scan result policy reads' do
      it 'returns all associated project approval settings for a single project' do
        approval_settings = framework.approval_settings_from_security_policies(project1)

        expect(approval_settings).to contain_exactly(
          { "prevent_approval_by_author" => true },
          { "block_branch_modification" => true }
        )
      end

      it 'returns all associated project approval settings for multiple projects' do
        approval_settings = framework.approval_settings_from_security_policies([project1, project2])

        expect(approval_settings).to contain_exactly(
          { "prevent_approval_by_author" => true },
          { "prevent_approval_by_commit_author" => true },
          { "block_branch_modification" => true }
        )
      end

      it 'returns empty array for a project with no policy reads' do
        project3 = create(:project)

        expect(framework.approval_settings_from_security_policies(project3)).to eq([])
      end
    end
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:namespace) { create(:group) }

    describe '.with_projects' do
      before do
        create(:compliance_framework_project_setting, :first_framework, project: project)
        create(:compliance_framework_project_setting, :second_framework, project: project)
      end

      it 'returns frameworks associated with given project ids in order of addition' do
        frameworks = described_class.with_projects([project.id])

        expect(frameworks.map(&:name)).to eq(['First Framework', 'Second Framework'])
      end
    end

    describe '.for_namespaces' do
      let_it_be(:other_namespace) { create(:group) }
      let_it_be(:framework_a) { create(:compliance_framework, namespace: namespace, name: 'A') }
      let_it_be(:framework_b) { create(:compliance_framework, namespace: namespace, name: 'B') }
      let_it_be(:framework_c) { create(:compliance_framework, namespace: other_namespace, name: 'C') }

      it 'returns frameworks whose namespace_id is in the given list' do
        expect(described_class.for_namespaces([namespace.id])).to contain_exactly(framework_a, framework_b)
      end

      it 'returns frameworks across multiple namespaces' do
        expect(described_class.for_namespaces([namespace.id, other_namespace.id]))
          .to contain_exactly(framework_a, framework_b, framework_c)
      end

      it 'filters directly on namespace_id without joining the namespaces table' do
        expect(described_class.for_namespaces([namespace.id]).to_sql).not_to include('JOIN "namespaces"')
      end
    end

    describe '.ordered_by_addition_time_and_pipeline_existence' do
      before do
        create(:compliance_framework_project_setting, :first_framework, project: project)
        create(:compliance_framework_project_setting, :second_framework, project: project)
        create(:compliance_framework_project_setting, :third_framework, project: project)
        create(:compliance_framework_project_setting,
          compliance_management_framework: create(:compliance_framework,
            pipeline_configuration_full_path: 'path/to/pipeline',
            name: 'Framework with pipeline'),
          project: project, created_at: 5.days.ago
        )
      end

      it 'left joins the table correctly' do
        sql = described_class.ordered_by_addition_time_and_pipeline_existence.to_sql

        expect(sql).to include('LEFT OUTER JOIN "project_compliance_framework_settings')
      end

      it 'returns frameworks in order of their addition time' do
        ordered_frameworks = described_class.ordered_by_addition_time_and_pipeline_existence

        expect(ordered_frameworks.pluck(:name)).to eq(['Framework with pipeline', 'First Framework',
          'Second Framework', 'Third Framework'])
      end
    end

    describe '.with_active_controls' do
      let_it_be(:framework, freeze: false) { create(:compliance_framework) }
      let_it_be(:requirement) { create(:compliance_requirement, framework: framework) }
      let_it_be(:internal_control) do
        create(:compliance_requirements_control, compliance_requirement: requirement)
      end

      let_it_be(:project_setting) do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework,
          project: project
        )
      end

      let_it_be(:framework_without_controls) { create(:compliance_framework) }
      let_it_be(:framework_without_projects) { create(:compliance_framework) }

      before do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_without_controls,
          project: project
        )

        requirement2 = create(:compliance_requirement, framework: framework_without_projects)
        create(:compliance_requirements_control, compliance_requirement: requirement2)
      end

      it 'includes frameworks with both controls and project settings' do
        result = described_class.with_active_controls

        expect(result).to include(framework)
      end

      it 'excludes frameworks without controls' do
        result = described_class.with_active_controls

        expect(result).not_to include(framework_without_controls)
      end

      it 'excludes frameworks without project settings' do
        result = described_class.with_active_controls

        expect(result).not_to include(framework_without_projects)
      end

      it 'returns unique results' do
        result = described_class.with_active_controls

        expect(result.count).to eq(result.distinct.count)
      end
    end
  end

  describe '.active_framework_ids' do
    let_it_be(:framework1) { create(:compliance_framework) }
    let_it_be(:framework2) { create(:compliance_framework) }
    let_it_be(:framework3) { create(:compliance_framework) }
    let_it_be(:project) { create(:project) }

    before do
      requirement1 = create(:compliance_requirement, framework: framework1)
      create(:compliance_requirements_control, compliance_requirement: requirement1)
      create(:compliance_framework_project_setting,
        compliance_management_framework: framework1,
        project: project
      )

      requirement2 = create(:compliance_requirement, framework: framework2)
      create(:compliance_requirements_control, compliance_requirement: requirement2)
      create(:compliance_framework_project_setting,
        compliance_management_framework: framework2,
        project: project
      )

      create(:compliance_framework_project_setting,
        compliance_management_framework: framework3,
        project: project
      )
    end

    it 'returns IDs of frameworks with active controls' do
      result = described_class.active_framework_ids

      expect(result).to contain_exactly(framework1.id, framework2.id)
    end

    it 'excludes frameworks without controls' do
      result = described_class.active_framework_ids

      expect(result).not_to include(framework3.id)
    end

    it 'returns an array' do
      expect(described_class.active_framework_ids).to be_an(Array)
    end

    it 'returns an empty array when no active frameworks exist' do
      described_class.delete_all

      expect(described_class.active_framework_ids).to eq([])
    end
  end

  describe '.with_project_coverage_for' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:project1) { create(:project, group: namespace) }
    let_it_be(:project2) { create(:project, group: namespace) }
    let_it_be(:project3) { create(:project, group: namespace) }

    let_it_be(:framework1) { create(:compliance_framework, namespace: namespace, name: 'Framework 1') }
    let_it_be(:framework2) { create(:compliance_framework, namespace: namespace, name: 'Framework 2') }
    let_it_be(:framework3) { create(:compliance_framework, namespace: namespace, name: 'Framework 3') }

    before do
      create(:compliance_framework_project_setting, compliance_management_framework: framework1, project: project1)
      create(:compliance_framework_project_setting, compliance_management_framework: framework1, project: project2)

      create(:compliance_framework_project_setting, compliance_management_framework: framework2, project: project1)
    end

    it 'returns frameworks with covered_count for specified projects' do
      results = described_class.with_project_coverage_for([project1.id, project2.id])

      expect(results.find { |f| f.name == 'Framework 1' }.covered_count).to eq(2)
      expect(results.find { |f| f.name == 'Framework 2' }.covered_count).to eq(1)
      expect(results.find { |f| f.name == 'Framework 3' }.covered_count).to eq(0)
    end
  end

  describe '.needing_attention_for_group' do
    let_it_be(:root_group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: root_group) }
    let_it_be(:another_root_group) { create(:group) }

    let_it_be(:framework_with_projects_and_requirements) do
      create(:compliance_framework, namespace: root_group, name: 'Framework with both')
    end

    let_it_be(:framework_without_projects) do
      create(:compliance_framework, namespace: root_group, name: 'Framework without projects')
    end

    let_it_be(:framework_without_requirements) do
      create(:compliance_framework, namespace: root_group, name: 'Framework without requirements')
    end

    let_it_be(:framework_in_different_namespace) do
      create(:compliance_framework, namespace: another_root_group, name: 'Framework in different namespace')
    end

    let_it_be(:project_in_root) { create(:project, namespace: root_group) }
    let_it_be(:project_in_subgroup) { create(:project, namespace: subgroup) }
    let_it_be(:project_in_another_namespace) { create(:project, namespace: another_root_group) }

    before do
      create(:compliance_framework_project_setting,
        compliance_management_framework: framework_with_projects_and_requirements,
        project: project_in_root
      )
      requirement = create(:compliance_requirement, framework: framework_with_projects_and_requirements)
      create(:compliance_requirements_control, compliance_requirement: requirement)

      create(:compliance_requirement, framework: framework_without_projects)

      create(:compliance_framework_project_setting,
        compliance_management_framework: framework_without_requirements,
        project: project_in_root
      )

      create(:compliance_framework_project_setting,
        compliance_management_framework: framework_in_different_namespace,
        project: project_in_another_namespace
      )
      create(:compliance_requirement, framework: framework_in_different_namespace)
    end

    context 'when querying from root group' do
      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

      it 'returns frameworks needing attention' do
        expect(frameworks.map(&:name)).to contain_exactly(
          'Framework without projects',
          'Framework without requirements'
        )
      end

      it 'excludes frameworks with both projects and requirements' do
        expect(frameworks).not_to include(framework_with_projects_and_requirements)
      end

      it 'includes correct counts' do
        framework_no_projects = frameworks.find { |f| f.name == 'Framework without projects' }
        framework_no_requirements = frameworks.find { |f| f.name == 'Framework without requirements' }

        expect(framework_no_projects.projects_count).to eq(0)
        expect(framework_no_projects.requirements_count).to eq(1)

        expect(framework_no_requirements.projects_count).to eq(1)
        expect(framework_no_requirements.requirements_count).to eq(0)
      end
    end

    context 'when querying from subgroup' do
      let_it_be(:framework_with_subgroup_project) do
        create(:compliance_framework, namespace: root_group, name: 'Framework with subgroup project')
      end

      before do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_with_subgroup_project,
          project: project_in_subgroup
        )
        requirement = create(:compliance_requirement, framework: framework_with_subgroup_project)
        create(:compliance_requirements_control, compliance_requirement: requirement)
      end

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(subgroup) }

      it 'counts only projects within the subgroup hierarchy' do
        expect(frameworks.map(&:name)).to contain_exactly(
          'Framework with both',
          'Framework without projects',
          'Framework without requirements'
        )
      end

      it 'returns correct project counts for subgroup context' do
        framework_no_requirements = frameworks.find { |f| f.name == 'Framework without requirements' }

        expect(framework_no_requirements.projects_count).to eq(0)
        expect(framework_no_requirements.requirements_count).to eq(0)
      end

      it 'excludes frameworks with projects in the subgroup' do
        expect(frameworks).not_to include(framework_with_subgroup_project)
      end
    end

    context 'when framework has requirements without controls' do
      let_it_be(:framework_with_missing_controls) do
        create(:compliance_framework, namespace: root_group, name: 'Framework with missing controls')
      end

      let_it_be(:framework_with_all_controls) do
        create(:compliance_framework, namespace: root_group, name: 'Framework with all controls')
      end

      before do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_with_missing_controls,
          project: project_in_root
        )

        requirement1 = create(:compliance_requirement, framework: framework_with_missing_controls)
        create(:compliance_requirement, framework: framework_with_missing_controls)

        create(:compliance_requirements_control, compliance_requirement: requirement1)

        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_with_all_controls,
          project: project_in_root
        )

        requirement3 = create(:compliance_requirement, framework: framework_with_all_controls)
        create(:compliance_requirements_control, compliance_requirement: requirement3)
      end

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

      it 'includes framework with requirements missing controls' do
        expect(frameworks.map(&:name)).to include('Framework with missing controls')
      end

      it 'excludes framework where all requirements have controls' do
        expect(frameworks).not_to include(framework_with_all_controls)
      end

      it 'returns correct counts for framework with missing controls' do
        framework = frameworks.find { |f| f.name == 'Framework with missing controls' }

        expect(framework.projects_count).to eq(1)
        expect(framework.requirements_count).to eq(2)
      end
    end

    context 'when group has no projects' do
      let_it_be(:empty_group) { create(:group, parent: root_group) }

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(empty_group) }

      it 'returns all frameworks as needing attention' do
        expect(frameworks.count).to be >= 2
      end
    end

    context 'when framework has multiple projects' do
      let_it_be(:framework_with_multiple_projects) do
        create(:compliance_framework, namespace: root_group, name: 'Framework with multiple projects')
      end

      before do
        requirement = create(:compliance_requirement, framework: framework_with_multiple_projects)
        create(:compliance_requirements_control, compliance_requirement: requirement)

        3.times do
          project = create(:project, namespace: root_group)
          create(:compliance_framework_project_setting,
            compliance_management_framework: framework_with_multiple_projects,
            project: project
          )
        end
      end

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

      it 'counts distinct projects correctly' do
        expect(frameworks).not_to include(framework_with_multiple_projects)
      end
    end

    context 'when framework has no associations' do
      let_it_be(:empty_framework) do
        create(:compliance_framework, namespace: root_group, name: 'Empty framework')
      end

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

      it 'includes framework with no projects and no requirements' do
        expect(frameworks.map(&:name)).to include('Empty framework')
      end

      it 'shows zero counts for empty framework' do
        empty = frameworks.find { |f| f.name == 'Empty framework' }

        expect(empty.projects_count).to eq(0)
        expect(empty.requirements_count).to eq(0)
      end
    end

    context 'when framework meets multiple conditions' do
      let_it_be(:framework_no_projects_no_requirements) do
        create(:compliance_framework, namespace: root_group, name: 'Framework with nothing')
      end

      let_it_be(:framework_no_projects_missing_controls) do
        create(:compliance_framework, namespace: root_group, name: 'Framework no projects missing controls')
      end

      before do
        create(:compliance_requirement, framework: framework_no_projects_missing_controls)
      end

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

      it 'includes frameworks meeting multiple conditions' do
        expect(frameworks.map(&:name)).to include(
          'Framework with nothing',
          'Framework no projects missing controls'
        )
      end

      it 'returns correct counts' do
        framework_nothing = frameworks.find { |f| f.name == 'Framework with nothing' }
        framework_no_proj_missing_ctrl = frameworks.find { |f| f.name == 'Framework no projects missing controls' }

        expect(framework_nothing.projects_count).to eq(0)
        expect(framework_nothing.requirements_count).to eq(0)

        expect(framework_no_proj_missing_ctrl.projects_count).to eq(0)
        expect(framework_no_proj_missing_ctrl.requirements_count).to eq(1)
      end
    end

    context 'when requirement has multiple controls' do
      let_it_be(:framework_with_multiple_controls) do
        create(:compliance_framework, namespace: root_group, name: 'Framework with multiple controls')
      end

      before do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_with_multiple_controls,
          project: project_in_root
        )

        requirement = create(:compliance_requirement, framework: framework_with_multiple_controls)

        # Create multiple controls for the same requirement
        create(:compliance_requirements_control, compliance_requirement: requirement)
        create(:compliance_requirements_control, :external, compliance_requirement: requirement)
      end

      subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

      it 'excludes framework where all requirements have controls' do
        expect(frameworks).not_to include(framework_with_multiple_controls)
      end
    end

    context 'when framework has projects in root but viewed from subgroup' do
      let_it_be(:framework_complex) do
        create(:compliance_framework, namespace: root_group, name: 'Complex framework')
      end

      before do
        create(:compliance_framework_project_setting,
          compliance_management_framework: framework_complex,
          project: project_in_root
        )

        req_with_control = create(:compliance_requirement, framework: framework_complex)
        create(:compliance_requirement, framework: framework_complex)

        create(:compliance_requirements_control, compliance_requirement: req_with_control)
      end

      context 'when root group is passed' do
        subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(root_group) }

        it 'includes framework due to missing controls' do
          expect(frameworks.map(&:name)).to include('Complex framework')
        end
      end

      context 'when sub group is passed' do
        subject(:frameworks) { root_group.compliance_management_frameworks.needing_attention_for_group(subgroup) }

        it 'includes framework due to no projects in subgroup' do
          expect(frameworks.map(&:name)).to include('Complex framework')

          framework = frameworks.find { |f| f.name == 'Complex framework' }
          expect(framework.projects_count).to eq(0)
        end
      end
    end
  end
end
