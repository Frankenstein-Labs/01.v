# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Handlers::Notes::CopyService, feature_category: :team_planning do
  describe '#execute' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:user2) { create(:user) }
    let_it_be(:group) { create(:group, developers: [current_user]) }
    let_it_be(:target_group) { create(:group, developers: [current_user]) }

    let_it_be_with_reload(:work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
    let_it_be_with_reload(:target_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: target_group) }

    let_it_be(:label_event) { create(:resource_label_event, issue: work_item) }
    let_it_be(:milestone_event) { create(:resource_milestone_event, issue: work_item) }
    let_it_be(:state_event) { create(:resource_state_event, issue: work_item) }

    let_it_be(:system_note_with_epic_id_with_description_version_metadata) do
      create(:system_note, namespace: work_item.namespace, noteable: work_item).tap do |system_note|
        description_version = create(:description_version, epic: work_item.sync_object)
        create(:system_note_metadata, description_version: description_version, note: system_note)
      end
    end

    let_it_be(:system_note_with_issue_id_with_description_version_metadata) do
      create(:system_note, namespace: work_item.namespace, noteable: work_item).tap do |system_note|
        description_version = create(:description_version, issue: work_item)
        create(:system_note_metadata, description_version: description_version, note: system_note)
      end
    end

    subject(:execute_service) { described_class.new(current_user, work_item, target_work_item).execute }

    it 'copies description_versions from work_item to target_work_item', :aggregate_failures do
      expect { execute_service }.to change {
        DescriptionVersion.where(issue_id: target_work_item.id, namespace_id: target_group).count
      }.by(2)

      expect(target_work_item.sync_object.description_versions.map(&:description)).to match_array(
        work_item.sync_object.description_versions.map(&:description)
      )
    end
  end
end
