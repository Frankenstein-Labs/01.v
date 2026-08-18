# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::WidgetDefinitions::HierarchyType, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:root_group) { create(:group, organization: organization) }
  let_it_be(:converted_task) do
    create(:work_item_custom_type, :converted_from_task, :with_organization, organization: organization,
      name: 'Subtask')
  end

  let(:issue_type) { build(:work_item_system_defined_type, :issue) }
  let(:task_type) { build(:work_item_system_defined_type, :task) }
  let(:user) { create(:user) }
  let(:widget_definition) do
    build(:work_item_system_defined_widget_definition, widget_type: 'hierarchy',
      work_item_type_id: issue_type.id)
  end

  before do
    stub_licensed_features(configurable_work_item_types: true)
  end

  describe '#allowed_child_types' do
    subject(:result) do
      resolve_field(:allowed_child_types, widget_definition, ctx: { resource_parent: root_group },
        current_user: user, extras: { parent: issue_type })
    end

    it 'returns custom type instead of replaced system type' do
      names = result.map(&:name)

      expect(names).to include('Subtask')
      expect(names).not_to include('Task')
    end

    context 'when resource_parent is nil' do
      subject(:result) do
        resolve_field(:allowed_child_types, widget_definition, ctx: { resource_parent: nil },
          current_user: user, extras: { parent: issue_type })
      end

      it 'falls back to system-defined types' do
        names = result.map(&:name)

        expect(names).to include('Task')
        expect(names).not_to include('Subtask')
      end
    end
  end

  describe '#allowed_parent_types' do
    let_it_be(:converted_issue) do
      create(:work_item_custom_type, :converted_from_issue, :with_organization, organization: organization, name: 'Bug')
    end

    subject(:result) do
      resolve_field(:allowed_parent_types, widget_definition, ctx: { resource_parent: root_group },
        current_user: user, extras: { parent: task_type })
    end

    it 'returns custom type instead of replaced system type' do
      names = result.map(&:name)

      expect(names).to include('Bug')
      expect(names).not_to include('Issue')
    end

    context 'when resource_parent is nil' do
      subject(:result) do
        resolve_field(:allowed_parent_types, widget_definition, ctx: { resource_parent: nil },
          current_user: user, extras: { parent: task_type })
      end

      it 'falls back to system-defined types' do
        names = result.map(&:name)

        expect(names).to include('Issue')
        expect(names).not_to include('Bug')
      end
    end
  end
end
