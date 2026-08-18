# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::BulkImports::EpicObjectCreator, feature_category: :importers do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, owner_of: group) }

  let(:parent_class) do
    Class.new do
      def save_relation_object(relation_object, _relation_key, _relation_definition, _relation_index)
        relation_object
      end
    end
  end

  let(:test_class) do
    Class.new(parent_class) do
      include BulkImports::EpicObjectCreator

      attr_accessor :current_user

      def initialize(user)
        @current_user = user
      end
    end
  end

  let(:creator) { test_class.new(user) }

  before do
    stubbed_epic = build(:epic, group: group)
    stubbed_work_item = build(:work_item, id: 999)
    allow(stubbed_epic).to receive(:work_item).and_return(stubbed_work_item)

    allow(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService).to receive(:new).and_return(
      instance_double(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService, execute: stubbed_epic)
    )
  end

  describe '#save_relation_object' do
    context 'when relation_key is not epic-related' do
      it 'calls parent method for non-epic relations' do
        other_object = instance_double(Issue)
        result = creator.save_relation_object(other_object, 'other', {}, 0)
        expect(result).to eq(other_object)
      end
    end

    context 'when relation_key is epics' do
      let(:epic_obj) { instance_double(Epic, new_record?: true, :relative_position= => nil) }

      context 'for new records' do
        before do
          allow(epic_obj).to receive(:new_record?).and_return(true)
          allow(creator).to receive(:create_epic).with(epic_obj).and_return(epic_obj)
        end

        it 'calls create_epic' do
          expect(creator).to receive(:create_epic).with(epic_obj)
          creator.save_relation_object(epic_obj, 'epics', {}, 0)
        end

        it 'clears relative_position so PlacementWorker can position it after import' do
          expect(epic_obj).to receive(:relative_position=).with(nil)

          creator.save_relation_object(epic_obj, 'epics', {}, 0)
        end
      end

      context 'for persisted records' do
        before do
          allow(epic_obj).to receive(:new_record?).and_return(false)
        end

        it 'does not call create_epic' do
          expect(creator).not_to receive(:create_epic)
          creator.save_relation_object(epic_obj, 'epics', {}, 0)
        end
      end
    end

    context 'when relation_key is issues' do
      let(:issue) { instance_double(Issue, epic_issue: nil, 'epic_issue=': nil, project: project) }

      context 'when issue has epic_issue association' do
        let(:epic_issue_attributes) { { 'id' => 123, 'relative_position' => 1000 } }
        let(:source_epic) { instance_double(Epic) }
        let(:epic_issue) do
          instance_double(EpicIssue,
            attributes: epic_issue_attributes,
            epic: source_epic,
            relative_position: epic_issue_attributes['relative_position']
          )
        end

        before do
          allow(issue).to receive_messages(
            epic_issue: epic_issue,
            'epic_issue=': nil
          )
          allow(creator).to receive(:handle_issue_with_epic_association).and_return({ status: :success })
        end

        it 'extracts epic_issue data and clears association' do
          expect(issue).to receive(:epic_issue=).with(nil)
          expect(creator).to receive(:handle_issue_with_epic_association).with(
            issue,
            source_epic,
            1000
          )

          creator.save_relation_object(issue, 'issues', {}, 0)
        end

        it 'returns the result from handle_issue_with_epic_association' do
          result = creator.save_relation_object(issue, 'issues', {}, 0)
          expect(result).to eq({ status: :success })
        end
      end
    end
  end

  describe '#copy_epic_user_references_to_work_items' do
    let_it_be(:epic) { create(:epic, group: group) }
    let(:references) { { 'author_id' => 101 } }

    it 'copies each epic entry to its work item' do
      map = { epic => references }

      creator.send(:copy_epic_user_references_to_work_items, map)

      expect(map).to eq({ epic => references, epic.issue => references })
    end

    it 'ignores non-epic entries' do
      issue = create(:issue, project: project)
      map = { issue => references }

      expect { creator.send(:copy_epic_user_references_to_work_items, map) }.not_to change { map }
    end

    it 'ignores epics without a work item' do
      epic_without_work_item = build(:epic, group: group, issue_id: nil)
      map = { epic_without_work_item => references }

      expect { creator.send(:copy_epic_user_references_to_work_items, map) }.not_to change { map }
    end

    it 'keeps references the work item already has' do
      work_item_references = { 'updated_by_id' => 102 }
      map = { epic => references, epic.issue => work_item_references }

      creator.send(:copy_epic_user_references_to_work_items, map)

      expect(map[epic.issue]).to eq(work_item_references)
    end
  end

  describe 'epic creation' do
    let(:epic_obj) { build(:epic, group: group) }

    it 'uses the epic creation service when processing new epics' do
      service_double = instance_double(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService,
        execute: epic_obj)
      expect(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService).to receive(:new).with(
        group: group,
        current_user: user,
        epic_object: epic_obj
      ).and_return(service_double)

      expect(service_double).to receive(:execute).and_return(epic_obj)

      creator.save_relation_object(epic_obj, 'epics', {}, 0)
    end

    # The built object is cached by Gitlab::ImportExport::Base::ObjectBuilder for the whole job.
    # Leaving it as a new record makes every later reference to the same epic create it again,
    # which violates the unique index on issues (namespace_id, iid).
    it 'marks the built epic object as persisted once the service has created the epic' do
      created_epic = create(:epic, group: group)

      allow(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService).to receive(:new).and_return(
        instance_double(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService, execute: created_epic)
      )

      creator.save_relation_object(epic_obj, 'epics', {}, 0)

      expect(epic_obj).to be_persisted
      expect(epic_obj.id).to eq(created_epic.id)
    end

    it 'leaves the built epic object alone when the service does not persist an epic' do
      allow(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService).to receive(:new).and_return(
        instance_double(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService, execute: nil)
      )

      creator.save_relation_object(epic_obj, 'epics', {}, 0)

      expect(epic_obj).not_to be_persisted
    end
  end

  describe 'integration behavior' do
    context 'when processing issues with epic associations' do
      let(:issue) { create(:issue, project: project) }
      let(:epic_from_source) { build(:epic, title: 'Source Epic', group_id: 999) }
      let(:existing_epic) { create(:epic, title: 'Source Epic', group: group) }
      let(:work_item) { create(:work_item, :issue, project: project) }

      before do
        allow(WorkItem).to receive(:find_by_id).with(issue.id).and_return(work_item)
      end

      it 'processes epic associations when issue has epic_issue' do
        epic_issue_data = { 'relative_position' => 1000 }
        epic_issue = instance_double(EpicIssue,
          attributes: epic_issue_data.merge('id' => 123),
          epic: epic_from_source,
          relative_position: 1000
        )

        allow(issue).to receive_messages(
          epic_issue: epic_issue,
          'epic_issue=': nil
        )

        parent_links_service = instance_double(WorkItems::ParentLinks::CreateService)
        mock_parent_link = instance_double(WorkItems::ParentLink)

        expect(WorkItems::ParentLinks::CreateService).to receive(:new).with(any_args).and_return(parent_links_service)

        expect(parent_links_service).to receive(:execute).and_return({
          status: :success,
          created_references: [mock_parent_link]
        })

        mock_epic_issue = instance_double(EpicIssue)
        allow(work_item).to receive(:epic_issue).and_return(mock_epic_issue)

        result = creator.save_relation_object(issue, 'issues', {}, 0)

        expect(result).to eq(issue)
      end

      it 'handles the case when epic does not exist in destination group' do
        build(:epic, title: 'Source Epic', group: group)
        epic_issue_data = { 'relative_position' => 1000 }
        epic_issue = instance_double(EpicIssue,
          attributes: epic_issue_data.merge('id' => 123),
          epic: epic_from_source,
          relative_position: 1000
        )

        allow(issue).to receive_messages(
          epic_issue: epic_issue,
          'epic_issue=': nil
        )

        epic_creation_service = instance_double(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService,
          execute: existing_epic)

        expect(WorkItems::LegacyEpics::Imports::CreateFromImportedEpicService).to receive(:new).with(
          any_args).and_return(epic_creation_service)
        expect(epic_creation_service).to receive(:execute).and_return(existing_epic)

        parent_links_service = instance_double(WorkItems::ParentLinks::CreateService, execute: { status: :success })
        expect(WorkItems::ParentLinks::CreateService).to receive(:new).and_return(parent_links_service)
        expect(parent_links_service).to receive(:execute).and_return({ status: :success })

        result = creator.save_relation_object(issue, 'issues', {}, 0)

        expect(result).to eq(issue)
      end

      it 'sets the correct relative position on the parent link during epic association' do
        epic_issue_data = { 'relative_position' => 1500 }
        epic_issue = instance_double(EpicIssue,
          attributes: epic_issue_data.merge('id' => 123),
          epic: epic_from_source,
          relative_position: 1500
        )

        allow(issue).to receive_messages(
          epic_issue: epic_issue,
          'epic_issue=': nil
        )

        mock_parent_link = instance_double(WorkItems::ParentLink,
          relative_position: nil,
          'relative_position=': nil,
          work_item: work_item,
          work_item_parent: existing_epic.work_item
        )

        allow(mock_parent_link).to receive(:update_column).with(:relative_position, 1500)

        parent_links_service = instance_double(WorkItems::ParentLinks::CreateService)
        expect(WorkItems::ParentLinks::CreateService).to receive(:new).with(any_args).and_return(parent_links_service)

        expect(parent_links_service).to receive(:execute) do
          { status: :success, created_references: [mock_parent_link] }
        end

        allow(parent_links_service).to receive(:sync_relative_position).with(mock_parent_link) do |parent_link|
          expect(parent_link.relative_position).to eq(1500)
        end

        mock_work_item_epic_issue = instance_double(EpicIssue)
        allow(work_item).to receive(:epic_issue).and_return(mock_work_item_epic_issue)

        allow(mock_parent_link).to receive(:update_column).with(:relative_position, 1500)
        allow(mock_work_item_epic_issue).to receive(:update_column).with(:relative_position, 1500)

        result = creator.save_relation_object(issue, 'issues', {}, 0)

        expect(result).to eq(issue)
      end
    end
  end
end
