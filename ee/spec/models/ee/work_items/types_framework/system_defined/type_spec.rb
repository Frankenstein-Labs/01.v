# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::SystemDefined::Type, feature_category: :team_planning do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  describe 'resolved type configuration' do
    it_behaves_like 'work item type configuration', :creatable?, {
      epic: true,
      objective: true,
      key_result: true,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :configurable?, {
      epic: false,
      objective: true,
      key_result: true,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :visible_in_settings?, {
      epic: true,
      objective: true,
      key_result: true,
      test_case: true,
      requirement: true
    }

    it_behaves_like 'work item type configuration', :show_project_selector?, {
      epic: false,
      objective: true,
      key_result: true,
      test_case: true,
      requirement: true
    }

    it_behaves_like 'work item type configuration', :can_be_conversion_target?, {
      epic: true,
      objective: true,
      key_result: true,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :archived?, {
      epic: false,
      objective: false,
      key_result: false,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :only_for_group?, {
      epic: true,
      objective: false,
      key_result: false,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :supports_roadmap_view?, {
      epic: true,
      objective: false,
      key_result: false,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :use_legacy_view?, {
      epic: false,
      objective: false,
      key_result: false,
      test_case: true,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :supports_move_action?, {
      epic: false,
      objective: false,
      key_result: false,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :can_promote_to_objective?, {
      epic: false,
      objective: false,
      key_result: true,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :service_desk?, {
      epic: false,
      objective: false,
      key_result: false,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :incident_management?, {
      epic: false,
      objective: false,
      key_result: false,
      test_case: false,
      requirement: false
    }

    it_behaves_like 'work item type configuration', :supports_conversion?, {
      epic: false,
      objective: true,
      key_result: true,
      test_case: true,
      requirement: true
    }

    it_behaves_like 'work item type configuration', :disabled_workflow_type?, {
      epic: false,
      objective: false,
      key_result: false,
      test_case: true,
      requirement: true
    }

    it_behaves_like 'work item type configuration', :okr?, {
      epic: false,
      objective: true,
      key_result: true,
      test_case: false,
      requirement: false
    }
  end

  describe '.fixed_items' do
    it 'defines all expected work item types' do
      expect(described_class.fixed_items.size).to eq(9)
    end

    it 'includes Epic type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 8 }

      expect(type).to include(
        id: 8,
        name: 'Epic',
        base_type: 'epic',
        icon_name: 'work-item-epic'
      )
    end

    it 'includes Key Result type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 7 }

      expect(type).to include(
        id: 7,
        name: 'Key Result',
        base_type: 'key_result',
        icon_name: 'work-item-keyresult'
      )
    end

    it 'includes Objective type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 6 }

      expect(type).to include(
        id: 6,
        name: 'Objective',
        base_type: 'objective',
        icon_name: 'work-item-objective'
      )
    end

    it 'includes Requirement type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 4 }

      expect(type).to include(
        id: 4,
        name: 'Requirement',
        base_type: 'requirement',
        icon_name: 'work-item-requirement'
      )
    end

    it 'includes Test Case type with correct attributes' do
      type = described_class.fixed_items.find { |item| item[:id] == 3 }

      expect(type).to include(
        id: 3,
        name: 'Test Case',
        base_type: 'test_case',
        icon_name: 'work-item-test-case'
      )
    end

    it 'has unique IDs for all types' do
      ids = described_class.fixed_items.pluck(:id)

      expect(ids.uniq.size).to eq(ids.size)
    end

    it 'has unique base_types for all types' do
      base_types = described_class.fixed_items.pluck(:base_type)

      expect(base_types.uniq.size).to eq(base_types.size)
    end
  end

  describe '#supported_conversion_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }

    context 'with group as resource_parent' do
      let(:resource_parent) { group }

      it 'includes all types except the current type and non-convertible types' do
        result = issue_type.supported_conversion_types(resource_parent, user)
        included_types = %w[incident task]

        expect(result.map(&:base_type)).to match_array(included_types)
      end

      context "when supports_conversion? defaults to true" do
        let(:task_type) { build(:work_item_system_defined_type, :task) }

        before do
          stub_licensed_features(epics: true)
          resource_parent.add_developer(user)
        end

        it 'allows conversion when configuration does not define supports_conversion?' do
          result = task_type.supported_conversion_types(resource_parent, user)

          # Task type should support conversion by default
          expect(result).not_to be_empty
        end

        it 'excludes epic type for task conversion' do
          result = task_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include('epic')
        end
      end

      context "when the type does not supports_conversion (epic)" do
        let(:epic_type) { build(:work_item_system_defined_type, :epic) }

        it 'retutns an empty array' do
          result = epic_type.supported_conversion_types(resource_parent, user)

          expect(result).to eq([])
        end
      end

      context 'when all licensed features are available' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          resource_parent.add_developer(user)
        end

        it 'includes all types except the current type and non-convertible types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('epic', 'task', 'incident')
          expect(result.map(&:base_type)).not_to include('issue', 'requirement', 'test_case', 'ticket')
        end

        it 'orders results by name' do
          result = issue_type.supported_conversion_types(resource_parent, user)
          names = result.map(&:name)

          expect(names).to eq(names.sort_by(&:downcase))
        end
      end

      shared_examples 'when license is not available' do
        before do
          resource_parent.add_developer(user)
        end

        it 'excludes the type' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include(*excluded_types)
        end

        it 'includes other licensed types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          if included_types.empty?
            expect(result.map(&:base_type)).to match_array(%w[task incident])
          else
            expect(result.map(&:base_type)).to include(*included_types)
          end
        end
      end

      context 'when epics license is not available' do
        before do
          stub_licensed_features(epics: false, okrs: true, requirements: true)
        end

        let(:excluded_types) { %w[epic requirement test_case] }
        let(:included_types) { [] }

        it_behaves_like 'when license is not available'
      end

      context 'when requirements license is not available' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: false)
        end

        let(:excluded_types) { %w[requirement test_case] }
        let(:included_types) { %w[epic] }

        it_behaves_like 'when license is not available'
      end

      context 'when user cannot create epics' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          # User is not a member, so cannot create epics
        end

        it 'excludes epic type even if licensed' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include('epic')
        end

        it 'excludes non-convertible types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include('requirement', 'test_case', 'ticket')
        end
      end
    end

    shared_examples "for objective and key result" do
      before_all do
        group.add_developer(user)
      end

      context 'when okrs_mvc feature flag is enabled' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          stub_feature_flags(okrs_mvc: project)
        end

        it 'includes objective and key_result types' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('objective', 'key_result')
        end
      end

      context 'when okrs_mvc feature flag is disabled' do
        before do
          stub_licensed_features(epics: true, okrs: true, requirements: true)
          stub_feature_flags(okrs_mvc: false)
        end

        it 'excludes objective and key_result types even if licensed' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).not_to include('objective', 'key_result')
        end

        it 'includes other licensed types that support conversion' do
          result = issue_type.supported_conversion_types(resource_parent, user)

          expect(result.map(&:base_type)).to include('epic')
          expect(result.map(&:base_type)).not_to include('requirement', 'test_case')
        end
      end
    end

    context 'with project as resource_parent' do
      let(:resource_parent) { project }

      it_behaves_like "for objective and key result"
    end

    context 'with project namespace as resource_parent' do
      let(:resource_parent) { project.project_namespace }

      it_behaves_like "for objective and key result"
    end

    context 'with organization as resource_parent' do
      let(:resource_parent) { organization }

      before do
        stub_licensed_features(epics: true, requirements: true)
      end

      it 'excludes epics for organizations and non-convertible types' do
        result = issue_type.supported_conversion_types(resource_parent, user)

        expect(result.map(&:base_type)).not_to include('epic', 'requirement', 'test_case', 'ticket')
      end
    end

    context 'with nil as resource_parent' do
      it 'handles nil resource_parent gracefully' do
        result = issue_type.supported_conversion_types(nil, user)

        expect(result.map(&:base_type)).to match_array(%w[task incident])
      end
    end

    context 'with no licensed features' do
      before do
        stub_licensed_features(epics: false, okrs: false, requirements: false)
      end

      it 'returns only CE types that support conversion' do
        result = issue_type.supported_conversion_types(project, user)

        expect(result.map(&:base_type)).to match_array(%w[task incident])
      end
    end

    context 'with custom work item types in the namespace' do
      let_it_be(:root_group) { create(:group) }
      let_it_be(:resource_parent) { root_group }
      let(:issue_type) { build(:work_item_system_defined_type, :issue) }

      before do
        stub_licensed_features(configurable_work_item_types: true)
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      context 'when a custom type is converted from a system-defined type' do
        let_it_be(:converted_task) do
          create(:work_item_custom_type, :converted_from_task, namespace: root_group, name: 'Subtask')
        end

        it 'returns the converted custom type in place of the system-defined one' do
          names = issue_type.supported_conversion_types(resource_parent, user).map(&:name)

          expect(names).to include('Subtask')
          expect(names).not_to include('Task')
        end

        it 'still returns unreplaced system-defined types' do
          names = issue_type.supported_conversion_types(resource_parent, user).map(&:name)

          expect(names).to include('Incident')
        end
      end

      context 'with non-converted custom types sharing the source base_type' do
        let_it_be(:bug_type) do
          create(:work_item_custom_type, namespace: root_group, name: 'Bug')
        end

        let_it_be(:access_request_type) do
          create(:work_item_custom_type, namespace: root_group, name: 'Access request')
        end

        it 'includes non-converted customs whose base_type matches the CE-allowed list' do
          names = issue_type.supported_conversion_types(resource_parent, user).map(&:name)

          expect(names).to include('Bug', 'Access request')
        end

        context 'when the source is a non-converted custom type (custom-to-custom)' do
          it 'allows conversion to a sibling custom type sharing the same base_type' do
            names = bug_type.supported_conversion_types(resource_parent, user).map(&:name)

            expect(names).to include('Access request')
            expect(names).not_to include('Bug') # itself excluded
          end

          it 'still includes system-defined conversion targets' do
            names = bug_type.supported_conversion_types(resource_parent, user).map(&:name)

            expect(names).to include('Incident')
          end
        end
      end

      context 'when the source is a converted custom type' do
        let_it_be(:converted_issue) do
          create(:work_item_custom_type, :converted_from_issue, namespace: root_group, name: 'Converted Issue')
        end

        let_it_be(:converted_task) do
          create(:work_item_custom_type, :converted_from_task, namespace: root_group, name: 'Subtask')
        end

        it 'excludes itself and the system type it replaced' do
          names = converted_issue.supported_conversion_types(resource_parent, user).map(&:name)

          expect(names).not_to include('Converted Issue', 'Issue')
        end

        it 'includes other conversion targets' do
          names = converted_issue.supported_conversion_types(resource_parent, user).map(&:name)

          expect(names).to include('Incident', 'Subtask')
        end
      end

      context 'when the source has a non-issue base_type (converted from incident)' do
        let_it_be(:critical_incident) do
          create(:work_item_custom_type, :converted_from_incident,
            namespace: root_group, name: 'Critical Incident')
        end

        let_it_be(:sev1_incident) do
          create(:work_item_custom_type, :converted_from_incident,
            namespace: root_group, name: 'Sev1 Incident')
        end

        let_it_be(:bug_type) do
          create(:work_item_custom_type, namespace: root_group, name: 'Bug')
        end

        let_it_be(:converted_task) do
          create(:work_item_custom_type, :converted_from_task, namespace: root_group, name: 'Subtask')
        end

        subject(:result) do
          critical_incident.supported_conversion_types(resource_parent, user)
        end

        it 'retains the CE-allowed base_types for incident, with Provider substitutions' do
          names = result.map(&:name)

          expect(names).to include('Subtask') # Task replaced by converted Subtask
          expect(names).not_to include('Task', 'Incident')
        end

        it 'includes custom types whose base_type is CE-allowed (e.g. Bug on :issue)' do
          expect(result.map(&:name)).to include('Bug')
        end

        it 'includes sibling custom types sharing the source base_type (custom-to-custom)' do
          expect(result.map(&:name)).to include('Sev1 Incident')
        end

        it 'excludes itself from the list' do
          expect(result.map(&:name)).not_to include('Critical Incident')
        end
      end

      context 'when a custom type is archived' do
        let_it_be(:custom_types_project) { create(:project, group: root_group) }

        let_it_be(:archived_bug) do
          create(:work_item_custom_type, :archived, namespace: root_group, name: 'Archived bug')
        end

        let_it_be(:active_bug) do
          create(:work_item_custom_type, namespace: root_group, name: 'Active bug')
        end

        it 'excludes the archived custom type from the conversion list' do
          names = issue_type.supported_conversion_types(custom_types_project, user).map(&:name)

          expect(names).to include('Active bug')
          expect(names).not_to include('Archived bug')
        end
      end

      context 'when a custom type is disabled via the namespace visibility map' do
        let_it_be(:visibility_project) { create(:project, group: root_group) }

        let_it_be(:disabled_bug) do
          create(:work_item_custom_type, namespace: root_group, name: 'Disabled bug')
        end

        let_it_be(:enabled_bug) do
          create(:work_item_custom_type, namespace: root_group, name: 'Enabled bug')
        end

        before do
          create(:work_item_settings, namespace: root_group, customizable_type_visibility: true)
          create(:work_item_type_visibility, namespace: root_group,
            work_item_type_id: disabled_bug.id, enabled: false, propagate: true)
        end

        it 'excludes the disabled custom type from the conversion list' do
          names = issue_type.supported_conversion_types(visibility_project, user).map(&:name)

          expect(names).to include('Enabled bug')
          expect(names).not_to include('Disabled bug')
        end
      end
    end
  end

  describe '#descendant_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:task_type) { build(:work_item_system_defined_type, :task) }
    let(:ticket_type) { build(:work_item_system_defined_type, :ticket) }

    context 'with EE hierarchy including epics' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      it 'includes all child types' do
        descendants = epic_type.descendant_types

        # This will depend on your actual hierarchy configuration
        expect(descendants).to match_array([epic_type, issue_type, task_type, ticket_type])
      end
    end

    context 'with circular dependencies in EE types' do
      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      it 'handles circular epic → epic relationships' do
        # If epic can be parent and child of epic (with subepics)
        descendants = epic_type.descendant_types

        # Should not cause infinite loop
        expect { descendants }.not_to raise_error
      end

      it 'returns unique descendants only once' do
        descendants = epic_type.descendant_types

        # Check for uniqueness
        expect(descendants.uniq.size).to eq(descendants.size)
      end
    end

    context 'with sibling non-converted custom types in the namespace' do
      let_it_be(:descendant_namespace) { create(:group) }
      let_it_be(:non_converted_custom_type) do
        create(:work_item_custom_type, namespace: descendant_namespace, name: 'Bug')
      end

      before do
        stub_licensed_features(epics: true, subepics: true)
        stub_saas_features(namespace_scoped_work_item_types: true)
      end

      it 'augments a system parent\'s descendants with sibling custom types delegating to one of them' do
        # `non_converted_custom_type` delegates to Issue (a descendant of Epic), so it must
        # appear as a separate entry in Epic\'s descendants when a resource_parent is given.
        descendants = epic_type.descendant_types(resource_parent: descendant_namespace)

        expect(descendants.map(&:persistable_id)).to include(non_converted_custom_type.persistable_id)
      end

      it 'does not duplicate the sibling custom type' do
        descendants = epic_type.descendant_types(resource_parent: descendant_namespace)
        matches = descendants.select { |type| type.persistable_id == non_converted_custom_type.persistable_id }

        expect(matches.size).to eq(1)
      end

      it 'does not augment when resource_parent is not provided' do
        expect(epic_type.descendant_types.map(&:persistable_id))
          .not_to include(non_converted_custom_type.persistable_id)
      end
    end
  end

  describe '#allowed_child_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'without authorization' do
      it 'returns all allowed child types without license checks' do
        # Assuming issue can have tasks as children
        expect(issue_type.allowed_child_types(authorize: false)).to include(task_type)
      end

      it 'returns child types ordered by name' do
        child_types = issue_type.allowed_child_types(authorize: false)
        expect(child_types).to eq(child_types.sort_by { |t| t.name.downcase })
      end
    end

    context 'with authorization' do
      shared_examples "includes expected child types" do
        it 'returns the child in the child types array' do
          child_types = type.allowed_child_types(
            authorize: true,
            resource_parent: resource_parent
          )

          expect(child_types).to include(*expected_child_types)
        end
      end

      shared_examples "does not include expected child types" do
        it 'returns the child in the child types array' do
          child_types = type.allowed_child_types(
            authorize: true,
            resource_parent: resource_parent
          )

          expect(child_types).not_to include(*expected_child_types)
        end
      end

      context 'when resource_parent is present' do
        let(:resource_parent) { project }

        context 'with epics and subepic lisense' do
          before do
            stub_licensed_features(epics: true, subepics: true)
          end

          context "for epic type" do
            let(:type) { epic_type }
            let(:expected_child_types) { [issue_type, epic_type] }

            it_behaves_like 'includes expected child types'
          end

          context "for issue_type" do
            let(:type) { issue_type }
            let(:expected_child_types) { [task_type] }

            it_behaves_like 'includes expected child types'
          end
        end

        context 'without epics and subepic license' do
          before do
            stub_licensed_features(epics: false, subepics: false)
          end

          context "for epic type" do
            let(:type) { epic_type }
            let(:expected_child_types) { [epic_type, issue_type] }

            it_behaves_like 'does not include expected child types'
          end

          context "for issue type" do
            let(:type) { issue_type }
            let(:expected_child_types) { [task_type] }

            it_behaves_like 'includes expected child types'
          end
        end

        context 'with epics and without subepic license' do
          before do
            stub_licensed_features(epics: true, subepics: false)
          end

          context "for epic type" do
            let(:type) { epic_type }
            let(:expected_child_types) { [epic_type] }

            it_behaves_like 'does not include expected child types'
          end

          context "for issue type" do
            let(:type) { issue_type }
            let(:expected_child_types) { [task_type] }

            it_behaves_like 'includes expected child types'
          end
        end

        context 'without epics and with subepic license' do
          before do
            stub_licensed_features(epics: false, subepics: true)
          end

          context "for epic type" do
            let(:type) { epic_type }
            let(:expected_child_types) { [epic_type] }

            it_behaves_like 'includes expected child types'
          end

          context "for issue type" do
            let(:type) { issue_type }
            let(:expected_child_types) { [task_type] }

            it_behaves_like 'includes expected child types'
          end
        end

        # This context is to test when the licenses_for_relation exists, but there is no license for a type.
        # In the currect hierarchy this example does not exists, but adding the spec to cover it
        context "for licensed types, where there is no license check on the child" do
          before do
            epic_task_hierarchy = WorkItems::TypesFramework::SystemDefined::HierarchyRestriction
              .new(id: 10, parent_type_id: epic_type.id, child_type_id: task_type.id)
            allow(WorkItems::TypesFramework::SystemDefined::HierarchyRestriction).to receive(:where)
              .with(parent_type_id: epic_type.id)
              .and_return([epic_task_hierarchy])
          end

          context "for epic type" do
            let(:type) { epic_type }
            let(:expected_child_types) { [task_type] }

            it_behaves_like 'includes expected child types'
          end
        end
      end

      context "when resource_parent is nil" do
        let(:resource_parent) { nil }

        context "for epic_type" do
          let(:type) { epic_type }
          let(:expected_child_types) { [issue_type, epic_type] }

          it_behaves_like 'does not include expected child types'
        end

        context "for issue_type" do
          let(:type) { issue_type }
          let(:expected_child_types) { [task_type] }

          it_behaves_like 'includes expected child types'
        end
      end

      context 'when there are types with no licence for child' do
        let(:resource_parent) { project }
        let(:objective_type) { build(:work_item_system_defined_type, :objective) }
        let(:key_result_type) { build(:work_item_system_defined_type, :key_result) }

        context "for objective type" do
          let(:type) { objective_type }
          let(:expected_child_types) { [key_result_type] }

          it_behaves_like 'includes expected child types'
        end
      end
    end
  end

  describe '#allowed_parent_types' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:task_type) { build(:work_item_system_defined_type, :task) }

    context 'without authorization' do
      it 'returns all allowed parent types without license checks' do
        # Assuming task can have issue as parent
        expect(task_type.allowed_parent_types(authorize: false))
          .to include(issue_type)
      end

      it 'returns parent types ordered by name' do
        parent_types = task_type.allowed_parent_types(authorize: false)
        expect(parent_types).to eq(parent_types.sort_by { |t| t.name.downcase })
      end
    end

    context 'with authorization' do
      shared_examples "includes expected parent types" do
        it 'returns the parent in the parents types array' do
          types = type.allowed_parent_types(
            authorize: true,
            resource_parent: resource_parent
          )

          expect(types).to include(*expected_types)
        end
      end

      shared_examples "does not include expected parent types" do
        it 'does not return the parent in the parent types array' do
          types = type.allowed_parent_types(
            authorize: true,
            resource_parent: resource_parent
          )

          expect(types).not_to include(*expected_types)
        end
      end

      context 'when resource_parent is present' do
        let(:resource_parent) { project }

        context 'with epics and subepics license' do
          before do
            stub_licensed_features(epics: true, subepics: true)
          end

          context "for epic_type" do
            let(:type) { epic_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'includes expected parent types'
          end

          context "for issue_type" do
            let(:type) { issue_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'includes expected parent types'
          end

          context "for task_type" do
            let(:type) { task_type }
            let(:expected_types) { [issue_type] }

            it_behaves_like 'includes expected parent types'
          end
        end

        context 'without epics and subepics license' do
          before do
            stub_licensed_features(epics: false, subepics: false)
          end

          context "for epic_type" do
            let(:type) { epic_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'does not include expected parent types'
          end

          context "for issue_type" do
            let(:type) { issue_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'does not include expected parent types'
          end

          context "for task_type" do
            let(:type) { task_type }
            let(:expected_types) { [issue_type] }

            it_behaves_like 'includes expected parent types'
          end
        end

        context 'with epics and without subepics license' do
          before do
            stub_licensed_features(epics: true, subepics: false)
          end

          context "for epic_type" do
            let(:type) { epic_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'does not include expected parent types'
          end

          context "for issue_type" do
            let(:type) { issue_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'includes expected parent types'
          end

          context "for task_type" do
            let(:type) { task_type }
            let(:expected_types) { [issue_type] }

            it_behaves_like 'includes expected parent types'
          end
        end

        context 'without epics and with subepics license' do
          before do
            stub_licensed_features(epics: false, subepics: true)
          end

          context "for epic_type" do
            let(:type) { epic_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'includes expected parent types'
          end

          context "for issue_type" do
            let(:type) { issue_type }
            let(:expected_types) { [epic_type] }

            it_behaves_like 'does not include expected parent types'
          end

          context "for task_type" do
            let(:type) { task_type }
            let(:expected_types) { [issue_type] }

            it_behaves_like 'includes expected parent types'
          end
        end

        # This context is to test when the licenses_for_relation exists, but there is no license for a type.
        # In the currect hierarchy this example does not exists, but adding the spec to cover it
        context "for licensed types, where there is no license check on the parent" do
          before do
            epic_task_hierarchy = WorkItems::TypesFramework::SystemDefined::HierarchyRestriction
              .new(id: 10, parent_type_id: task_type.id, child_type_id: epic_type.id)
            allow(WorkItems::TypesFramework::SystemDefined::HierarchyRestriction).to receive(:where)
              .with(child_type_id: epic_type.id)
              .and_return([epic_task_hierarchy])
          end

          context "for epic type" do
            let(:type) { epic_type }
            let(:expected_types) { [task_type] }

            it_behaves_like 'includes expected parent types'
          end
        end

        context "when resource parent is a group" do
          let(:resource_parent) { group }

          context 'with epics and without subepics license' do
            before do
              stub_licensed_features(epics: true, subepics: false)
            end

            context "for epic_type" do
              let(:type) { epic_type }
              let(:expected_types) { [epic_type] }

              it_behaves_like 'does not include expected parent types'
            end

            context "for issue_type" do
              let(:type) { issue_type }
              let(:expected_types) { [epic_type] }

              it_behaves_like 'includes expected parent types'
            end

            context "for task_type" do
              let(:type) { task_type }
              let(:expected_types) { [issue_type] }

              it_behaves_like 'includes expected parent types'
            end
          end
        end
      end

      context "when resource_parent is nil" do
        let(:resource_parent) { nil }

        context "for epic_type" do
          let(:type) { epic_type }
          let(:expected_types) { [epic_type] }

          it_behaves_like 'does not include expected parent types'
        end

        context "for issue_type" do
          let(:type) { issue_type }
          let(:expected_types) { [epic_type] }

          it_behaves_like 'does not include expected parent types'
        end

        context "for task_type" do
          let(:type) { task_type }
          let(:expected_types) { [issue_type] }

          it_behaves_like 'includes expected parent types'
        end
      end
    end
  end

  describe '#widgets' do
    let(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }

    context 'with project as resource_parent' do
      context 'when all licensed features are available' do
        before do
          stub_licensed_features(
            iterations: true,
            issue_weights: true,
            issuable_health_status: true,
            okrs: true,
            epic_colors: true,
            custom_fields: true,
            security_dashboard: true,
            work_item_status: true,
            requirements: true,
            ai_workflows: true
          )
        end

        it 'includes widgets from the super method' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          # Should include both CE and EE widgets
          expect(widget_types).to include('assignees', 'description', 'labels')
        end

        it 'includes licensed widgets when licenses are available' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('vulnerabilities', 'weight', 'health_status', 'agent_plan')
        end

        context 'when the agent_plan feature flag is disabled for the root ancestor' do
          before do
            # Enabling for an unrelated group leaves it disabled for the project's root_ancestor.
            stub_feature_flags(workplan: create(:group))
          end

          it 'excludes the agent_plan widget' do
            widget_types = issue_type.widgets(project).map(&:widget_type)

            expect(widget_types).not_to include('agent_plan')
          end
        end
      end

      context 'when some licensed features are not available' do
        before do
          stub_licensed_features(
            issue_weights: true,
            issuable_health_status: false,
            custom_fields: false,
            work_item_status: false,
            ai_workflows: false
          )
        end

        it 'excludes widgets that require unavailable licenses' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).not_to include('status', 'health_status', 'custom_fields', 'agent_plan')
        end

        it 'includes widgets with available licenses' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('weight')
        end

        it 'includes CE widgets that do not require licenses' do
          widgets = issue_type.widgets(project)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('assignees', 'description', 'labels', 'milestone')
        end
      end
    end

    context 'with group as resource_parent' do
      context 'when licensed features are available' do
        before do
          stub_licensed_features(
            issuable_health_status: true,
            issue_weights: true,
            epics: true
          )
        end

        it 'includes licensed widgets for group' do
          widgets = epic_type.widgets(group)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('health_status', 'weight')
        end

        it 'includes CE widgets' do
          widgets = epic_type.widgets(group)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('description', 'labels')
        end
      end

      context 'when licensed features are not available' do
        before do
          stub_licensed_features(
            iterations: false,
            issue_weights: false
          )
        end

        it 'excludes unlicensed widgets' do
          widgets = epic_type.widgets(group)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).not_to include('iteration', 'weight')
        end
      end
    end

    context 'with organization as resource_parent' do
      context 'when all licensed features are available' do
        before do
          stub_licensed_features(
            iterations: true,
            issue_weights: true,
            issuable_health_status: true,
            okrs: true,
            epic_colors: true,
            custom_fields: true,
            security_dashboard: true,
            work_item_status: true,
            requirements: true,
            ai_workflows: true
          )
        end

        it 'includes licensed widgets for organization' do
          widgets = issue_type.widgets(organization)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('vulnerabilities', 'weight', 'health_status', 'agent_plan')
        end

        it 'includes CE widgets' do
          widgets = issue_type.widgets(organization)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).to include('assignees', 'description', 'labels')
        end
      end

      context 'when licensed features are not available' do
        before do
          stub_licensed_features(
            iterations: false,
            issue_weights: false,
            issuable_health_status: false
          )
        end

        it 'excludes unlicensed widgets' do
          widgets = issue_type.widgets(organization)
          widget_types = widgets.map(&:widget_type)

          expect(widget_types).not_to include('iteration', 'weight', 'health_status')
        end
      end
    end
  end

  describe "for lifecycles" do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:other_namespace) { create(:group) }
    let_it_be(:work_item_type) { build(:work_item_system_defined_type, :issue) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    describe '#status_lifecycle_for' do
      let(:system_defined_lifecycle) { build(:work_item_system_defined_lifecycle) }

      subject(:status_lifecycle_for) { work_item_type.status_lifecycle_for(namespace_id) }

      context 'when custom lifecycle exists for the namespace' do
        let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }
        let(:namespace_id) { namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type: work_item_type,
            namespace: namespace,
            lifecycle: custom_lifecycle)
        end

        it 'returns the custom lifecycle' do
          expect(status_lifecycle_for).to eq(custom_lifecycle)
        end
      end

      context 'when custom lifecycle does not exist for the namespace' do
        let(:namespace_id) { namespace.id }

        it 'returns the system-defined lifecycle' do
          expect(status_lifecycle_for).to eq(system_defined_lifecycle)
        end
      end

      context 'when namespace_id is nil' do
        let(:namespace_id) { nil }

        it 'returns the system-defined lifecycle' do
          expect(status_lifecycle_for).to eq(system_defined_lifecycle)
        end
      end

      context 'when custom lifecycle exists for a different namespace' do
        let_it_be(:other_custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_namespace) }
        let(:namespace_id) { namespace.id }

        before do
          create(:work_item_type_custom_lifecycle,
            work_item_type: work_item_type,
            namespace: other_namespace,
            lifecycle: other_custom_lifecycle)
        end

        it 'returns the system-defined lifecycle for the original namespace' do
          expect(status_lifecycle_for).to eq(system_defined_lifecycle)
        end
      end
    end

    describe '#custom_status_enabled_for?' do
      subject(:custom_status_enabled_for) { work_item_type.custom_status_enabled_for?(namespace_id) }

      context 'when namespace_id is nil' do
        let(:namespace_id) { nil }

        it { is_expected.to be false }
      end

      context 'when namespace_id is provided' do
        let(:namespace_id) { namespace.id }

        context 'when custom lifecycle exists for the namespace' do
          let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

          before do
            create(:work_item_type_custom_lifecycle,
              work_item_type: work_item_type,
              namespace: namespace,
              lifecycle: custom_lifecycle)
          end

          it { is_expected.to be true }
        end

        context 'when custom lifecycle does not exist for the namespace' do
          it { is_expected.to be false }
        end
      end
    end

    describe '#custom_lifecycle_for' do
      subject(:custom_lifecycle_for) { work_item_type.custom_lifecycle_for(namespace_id) }

      context 'when namespace_id is nil' do
        let(:namespace_id) { nil }

        it 'returns nil' do
          expect(custom_lifecycle_for).to be_nil
        end
      end

      context 'when namespace_id is provided' do
        let(:namespace_id) { namespace.id }

        context 'when no custom lifecycle exists' do
          it 'returns nil' do
            expect(custom_lifecycle_for).to be_nil
          end
        end

        context 'when a custom lifecycle exists for a different namespace' do
          let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_namespace) }

          before do
            create(:work_item_type_custom_lifecycle,
              work_item_type: work_item_type,
              namespace: other_namespace,
              lifecycle: custom_lifecycle
            )
          end

          it 'returns nil' do
            expect(custom_lifecycle_for).to be_nil
          end
        end

        context 'when a custom lifecycle exists for a different work item type' do
          let_it_be(:other_work_item_type) { build(:work_item_system_defined_type, :task) }
          let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

          before do
            create(:work_item_type_custom_lifecycle,
              work_item_type: other_work_item_type,
              namespace: namespace,
              lifecycle: custom_lifecycle
            )
          end

          it 'returns nil' do
            expect(custom_lifecycle_for).to be_nil
          end
        end

        context 'when a custom lifecycle exists for the namespace and work item type' do
          let_it_be(:custom_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }

          before do
            create(:work_item_type_custom_lifecycle,
              work_item_type: work_item_type,
              namespace: namespace,
              lifecycle: custom_lifecycle
            )
          end

          it 'returns the custom lifecycle' do
            expect(custom_lifecycle_for).to eq(custom_lifecycle)
          end
        end

        context 'when multiple custom lifecycles exist but only one matches' do
          let_it_be(:matching_lifecycle) { create(:work_item_custom_lifecycle, namespace: namespace) }
          let_it_be(:other_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_namespace) }

          before do
            create(:work_item_type_custom_lifecycle,
              work_item_type: work_item_type,
              namespace: namespace,
              lifecycle: matching_lifecycle
            )

            create(:work_item_type_custom_lifecycle,
              work_item_type: work_item_type,
              namespace: other_namespace,
              lifecycle: other_lifecycle
            )
          end

          it 'returns only the matching lifecycle' do
            expect(custom_lifecycle_for).to eq(matching_lifecycle)
          end
        end
      end
    end

    describe '#system_defined_lifecycle' do
      let_it_be(:work_item_type) { build(:work_item_system_defined_type, :issue) }

      subject(:system_defined_lifecycle) { work_item_type.system_defined_lifecycle }

      it 'delegates to SystemDefined::Lifecycle.of_work_item_base_type' do
        expect(::WorkItems::Statuses::SystemDefined::Lifecycle)
          .to receive(:of_work_item_base_type)
          .with(work_item_type.base_type)
          .and_call_original

        system_defined_lifecycle
      end
    end
  end

  describe 'dynamic base_type methods' do
    let(:type_instance) { described_class.new(base_type: 'epic') }

    it 'returns true when base_type matches' do
      expect(type_instance.epic?).to be true
    end

    it 'returns false when base_type does not match' do
      expect(type_instance.requirement?).to be false
      expect(type_instance.objective?).to be false
      expect(type_instance.key_result?).to be false
      expect(type_instance.test_case?).to be false
    end
  end

  describe '#filterable_list_view?' do
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:requirement_type) { build(:work_item_system_defined_type, :requirement) }
    let(:test_case_type) { build(:work_item_system_defined_type, :test_case) }
    let(:objective_type) { build(:work_item_system_defined_type, :objective) }
    let(:key_result_type) { build(:work_item_system_defined_type, :key_result) }

    it 'returns true for epic type' do
      expect(epic_type.filterable_list_view?).to be true
    end

    it 'returns true for objective type' do
      expect(objective_type.filterable_list_view?).to be true
    end

    it 'returns true for key_result type' do
      expect(key_result_type.filterable_list_view?).to be true
    end

    it 'returns false for requirement type' do
      expect(requirement_type.filterable_list_view?).to be false
    end

    it 'returns false for test_case type' do
      expect(test_case_type.filterable_list_view?).to be false
    end
  end

  describe '#filterable_board_view?' do
    let(:epic_type) { build(:work_item_system_defined_type, :epic) }
    let(:requirement_type) { build(:work_item_system_defined_type, :requirement) }
    let(:test_case_type) { build(:work_item_system_defined_type, :test_case) }
    let(:objective_type) { build(:work_item_system_defined_type, :objective) }
    let(:key_result_type) { build(:work_item_system_defined_type, :key_result) }

    it 'returns false for all EE types', :aggregate_failures do
      [epic_type, requirement_type, test_case_type, objective_type, key_result_type].each do |type|
        expect(type.filterable_board_view?).to be false
      end
    end
  end
end
