# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  before_all do
    group.add_maintainer(user)
  end

  describe '#execute' do
    subject(:result) { described_class.new(group: group, current_user: user, epic_object: epic_object).execute }

    let_it_be(:parent_epic, freeze: false) { create(:epic, group: group) }
    let_it_be(:label) { create(:group_label, group: group) }

    let(:epic_object) do
      build(:epic,
        group: group,
        parent: parent_epic,
        relative_position: 1000,
        title: 'Epic Title',
        description: 'Epic Description',
        notes: [build(:note, noteable: nil, note: 'This is a test note')],
        award_emoji: [build(:award_emoji, name: 'thumbsup', user: user, awardable: nil)],
        label_links: [build(:label_link, label: label, target: nil)],
        events: [build(:event, :created)],
        resource_state_events: [build(:resource_state_event)]
      )
    end

    it 'creates a work item from the epic and returns the synced epic' do
      expect { result }.to change { WorkItem.count }.by(1).and change { Epic.count }.by(1)

      work_item = WorkItem.last
      expect(work_item).to eq(result.issue)

      expect([result.title, result.issue.title]).to all(eq(epic_object.title))

      expect(work_item).to have_attributes(
        description: epic_object.description,
        confidential: epic_object.confidential,
        namespace_id: epic_object.group_id
      )
      expect(result.author).to eq(user)

      expect(result.parent_id).to eq(parent_epic.id)
      expect(result.relative_position).to eq(epic_object.relative_position)
      expect(result.work_item_parent_link).to eq(work_item.parent_link)

      expect(work_item.award_emoji.count).to eq(1)
      expect(work_item.award_emoji.first).to have_attributes(
        name: 'thumbsup',
        awardable_type: 'Issue'
      )

      expect(work_item.labels.count).to eq(1)
      expect(work_item.labels.first).to eq(label)

      expect(work_item.notes.count).to eq(1)
      note = work_item.notes.first
      expect(note.note).to eq('This is a test note')
      expect(note.noteable_type).to eq('Issue')

      expect(work_item.events).not_to be_empty

      expect(work_item.resource_state_events).not_to be_empty
      expect(work_item.resource_state_events.first.state).to eq('opened') # Assuming initial state
    end

    it 'raises when epic work item is invalid' do
      epic_object.title = nil

      expect { result }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'importable associations' do
    it 'handles all associations specified in import_export.yml' do
      yml_path = Rails.root.join('lib/gitlab/import_export/group/import_export.yml')
      import_config = YAML.safe_load(
        File.read(yml_path),
        permitted_classes: [Symbol],
        aliases: true
      )

      yml_epic_data = import_config['ee']['tree']['group']
                                  .find { |item| item.is_a?(Hash) && item.key?("epics") }
                                  .fetch("epics")

      yml_symbol_associations = yml_epic_data.select { |attr| attr.is_a?(Symbol) }.map(&:to_s)
      yml_hash_associations = yml_epic_data.select { |attr| attr.is_a?(Hash) }.map { |h| h.each_key.first.to_s }
      all_yml_associations = yml_symbol_associations + yml_hash_associations

      handled_associations =
        ::WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService::ADDITIONAL_IMPORT_ASSOCIATIONS

      unhandled_associations = all_yml_associations - handled_associations

      expect(unhandled_associations).to be_empty,
        "These associations from import_export.yml are not handled by the service: #{unhandled_associations.join(', ')}"
    end
  end
end
