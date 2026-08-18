# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Hierarchy, :saas, feature_category: :team_planning do
  describe '#rolled_up_counts_by_type' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }

    before do
      stub_licensed_features(epics: true)
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    context 'when the namespace has a custom type converted from the descendant system type' do
      # When a system-defined type is converted to a custom type, the EE Provider returns
      # the custom NamespacedType wrapper for that system-defined id. The custom type's
      # AR primary key (`id`) differs from its `persistable_id`, which equals
      # `converted_from_system_defined_type_identifier` (the original system-defined id).
      # Existing work items still store `work_item_type_id` equal to the persistable_id,
      # so the grouped counts must be looked up using `persistable_id` to match.
      let_it_be(:parent_work_item) { create(:work_item, :issue, project: project) }
      let_it_be(:open_task) { create(:work_item, :task, :opened, project: project) }
      let_it_be(:closed_task) { create(:work_item, :task, :closed, project: project) }
      let_it_be(:converted_task_type) do
        create(:work_item_custom_type, :converted_from_task, namespace: group)
      end

      before_all do
        create(:parent_link, work_item_parent: parent_work_item, work_item: open_task)
        create(:parent_link, work_item_parent: parent_work_item, work_item: closed_task)
      end

      before do
        # The provider memoizes per work_item instance; clear so the converted type is picked up.
        parent_work_item.clear_memoization(:work_items_types_provider)
      end

      subject(:rolled_up_counts_by_type) { described_class.new(parent_work_item).rolled_up_counts_by_type }

      it 'returns correct counts for the converted descendant type', :aggregate_failures do
        task_counts = rolled_up_counts_by_type.find { |entry| entry[:work_item_type].base_type.to_s == 'task' }

        expect(task_counts).to be_present
        expect(task_counts[:work_item_type].persistable_id).not_to eq(task_counts[:work_item_type].id)
        expect(task_counts[:counts_by_state]).to eq(all: 2, opened: 1, closed: 1)
      end
    end

    context 'when an epic has non-converted custom type descendants delegating to Issue' do
      # Non-converted custom types delegate hierarchy semantics to their delegation_source
      # (Issue by default) but are persisted under their own AR primary key. They are
      # surfaced as separate entries in the rolled-up counts rather than folded into the
      # delegation source bucket, so the popover can list each custom type distinctly.
      let_it_be(:epic_parent) { create(:work_item, :epic, namespace: group) }
      let_it_be(:non_converted_custom_type) { create(:work_item_custom_type, namespace: group) }

      let_it_be(:open_custom_child) do
        create(:work_item, :issue, :opened, project: project, work_item_type: non_converted_custom_type)
      end

      let_it_be(:closed_custom_child) do
        create(:work_item, :issue, :closed, project: project, work_item_type: non_converted_custom_type)
      end

      let_it_be(:regular_open_issue) { create(:work_item, :issue, :opened, project: project) }

      before_all do
        [open_custom_child, closed_custom_child, regular_open_issue].each do |child|
          # `open_custom_child` and `closed_custom_child` have their `work_item_type_id`
          # overwritten via `update_column` to point at a non-converted custom type. The
          # ParentLink HasType validation cannot resolve that id through the system-defined
          # type framework, so we skip validations here while still persisting the link.
          build(:parent_link, work_item_parent: epic_parent, work_item: child).save!(validate: false)
        end
      end

      before do
        epic_parent.clear_memoization(:work_items_types_provider)
      end

      subject(:rolled_up_counts_by_type) { described_class.new(epic_parent).rolled_up_counts_by_type }

      it 'returns a separate entry for the non-converted custom type', :aggregate_failures do
        custom_entry = rolled_up_counts_by_type.find do |entry|
          entry[:work_item_type].is_a?(::WorkItems::TypesFramework::Custom::Type)
        end
        issue_entry = rolled_up_counts_by_type.find do |entry|
          entry[:work_item_type].base_type.to_s == 'issue' &&
            !entry[:work_item_type].is_a?(::WorkItems::TypesFramework::Custom::Type)
        end

        expect(custom_entry).to be_present
        expect(custom_entry[:work_item_type].id).to eq(non_converted_custom_type.id)
        expect(custom_entry[:counts_by_state]).to eq(all: 2, opened: 1, closed: 1)

        expect(issue_entry).to be_present
        expect(issue_entry[:counts_by_state]).to eq(all: 1, opened: 1, closed: 0)
      end
    end
  end
end
