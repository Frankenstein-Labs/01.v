# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::IssuesPipeline, feature_category: :importers do
  include Import::UserMappingHelper

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }
  let_it_be(:bulk_import, freeze: false) { create(:bulk_import, :with_configuration, user: user) }
  let_it_be(:filepath, freeze: false) { 'spec/fixtures/bulk_imports/gz/issues.ndjson.gz' }
  let_it_be(:entity, freeze: false) do
    create(
      :bulk_import_entity,
      :project_entity,
      project: project,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path',
      destination_slug: 'My-Destination-Project',
      destination_namespace: group.full_path
    )
  end

  let_it_be(:tracker, freeze: false) { create(:bulk_import_tracker, entity: entity) }
  let_it_be(:context, freeze: false) { BulkImports::Pipeline::Context.new(tracker) }

  let(:issue) do
    {
      'title' => 'title',
      'description' => 'Description',
      'state' => 'opened',
      'updated_at' => '2016-06-14T15:02:47.967Z',
      'author_id' => 22,
      'epic_issue' => {
        'id' => 78,
        'relative_position' => 1073740323,
        'epic' => {
          'title' => 'An epic',
          'state_id' => 'opened',
          'author_id' => 22
        }
      },

      'design_versions' => [
        {
          'sha' => 'cb1c33e9e3ece92b928c4f9b816a88e0ff28eba8',
          'created_at' => '2024-10-28T11:49:22.451Z',
          'author_id' => nil, # invalid author
          'actions' => [
            {
              'event' => 'creation',
              'design' => {
                'project_id' => project.id,
                'filename' => 'Screenshot_2024-10-24_at_17.47.27.png',
                'relative_position' => nil,
                'iid' => 1
              }
            }
          ]
        },
        {
          'sha' => '8f91cc8f88bb2b418f2cefb46e43737aa8feef19',
          'created_at' => '2024-10-28T11:49:47.218Z',
          'author_id' => 22,
          'actions' => [
            {
              'event' => 'deletion',
              'design' => {
                'project_id' => project.id,
                'filename' => 'Screenshot_2024-10-24_at_17.47.27.png',
                'relative_position' => nil,
                'iid' => 1
              }
            }
          ]
        },
        {
          'sha' => '4201e269f7edb652927f59ee44a8efe139067b4b',
          'created_at' => '2024-10-28T11:49:59.540Z',
          'author_id' => 22,
          'actions' => [
            {
              'event' => 'creation',
              'design' => {
                'project_id' => project.id,
                'filename' => 'Screenshot_2024-10-24_at_17.47.25.png',
                'relative_position' => nil,
                'iid' => 2
              }
            }
          ]
        }
      ]
    }
  end

  subject(:pipeline) { described_class.new(context) }

  describe '#run', :clean_gitlab_redis_shared_state do
    let_it_be(:source_user) do
      create(:import_source_user,
        import_type: ::Import::SOURCE_DIRECT_TRANSFER,
        namespace: group,
        source_user_identifier: 22,
        source_hostname: bulk_import.configuration.url,
        placeholder_user: create(:user, :import_user)
      )
    end

    before_all do
      group.add_owner(user)
    end

    before do
      stub_licensed_features(epics: true)
      allow(context).to receive(:importer_user_mapping_enabled?).and_return(true)

      issue_with_index = [issue, 0]

      allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
        allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [issue_with_index]))
      end

      allow(pipeline).to receive(:set_source_objects_counter)
    end

    context 'with pre-existing epic' do
      it 'associates existing epic with imported issue even when not all issue relations are valid' do
        epic = create(:epic, title: 'An epic', group: group)

        expect { pipeline.run }.not_to change { Epic.count }

        expect(group.epics.count).to eq(1)
        expect(project.issues.first.epic).to eq(epic)
        expect(project.issues.count).to eq(1)
        expect(project.issues.first.epic_issue.relative_position).not_to be_nil
        expect(project.issues.first.epic_issue.work_item_parent_link_id).to eq(project.work_items.first.parent_link.id)
        expect(project.work_items.first.parent_link.work_item_parent_id).to eq(epic.issue_id)

        group.epics.each do |epic|
          expect(epic.work_item).not_to be_nil

          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end
      end
    end

    context 'without pre-existing epic' do
      it 'creates a new epic for imported issue' do
        group.epics.delete_all

        expect { pipeline.run }.to change { Epic.count }.from(0).to(1)
        expect(group.epics.count).to eq(1)

        expect(project.issues.first.epic).not_to be_nil
        expect(project.issues.first.epic_issue.relative_position).not_to be_nil

        group.epics.each do |epic|
          expect(epic.work_item).not_to be_nil

          diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
          expect(diff.attributes).to be_empty
        end
      end
    end

    # ObjectBuilder caches the Epic it builds for the nested epic_issue.epic relation, but only
    # while Gitlab::SafeRequestStore is active -- true in Sidekiq, false in specs unless
    # :request_store is set. Without it this example passes even when the epic is created twice.
    context 'when two issues reference the same epic', :request_store do
      # Built per issue so both hold equal but distinct epic hashes, the way they arrive when each
      # ndjson line is deserialized on its own.
      def epic_hash
        { 'iid' => 20, 'title' => 'An epic', 'state_id' => 'opened', 'author_id' => 22 }
      end

      def issue_hash(iid:, title:)
        {
          'iid' => iid,
          'title' => title,
          'description' => 'Description',
          'state' => 'opened',
          'author_id' => 22,
          'epic_issue' => { 'relative_position' => 1073740323, 'epic' => epic_hash }
        }
      end

      before do
        entries = [issue_hash(iid: 1, title: 'First issue'), issue_hash(iid: 2, title: 'Second issue')]
        extracted_data = BulkImports::Pipeline::ExtractedData.new(data: entries.each_with_index.to_a)

        allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
          allow(extractor).to receive(:extract).and_return(extracted_data)
        end
      end

      it 'creates the shared epic only once and links both issues to it' do
        expect { pipeline.run }.to change { Epic.count }.by(1)

        failures = entity.failures.map { |failure| "#{failure.exception_class}: #{failure.exception_message}" }
        # Ordered relations rather than project.issues, whose association cache is shared between
        # examples by let_it_be.
        imported_issues = project.issues.order(:iid).to_a
        epic = group.epics.find_by!(iid: 20)

        expect(failures).to be_empty
        expect(imported_issues.map(&:title)).to eq(['First issue', 'Second issue'])
        expect(imported_issues.map { |issue| issue.epic_issue&.epic_id }).to eq([epic.id, epic.id])
      end
    end

    # A project imported on its own never runs EpicsPipeline, so the epic behind `epic_issue` is
    # created here. Both the Epic row and its work item need a reference: reassignment runs
    # `update_all` per referenced row and WorkItems::SyncAsEpic only syncs WorkItem -> Epic, so
    # referencing the epic alone leaves the work item -- the record the UI reads -- pointing at the
    # placeholder user.
    it 'pushes placeholder references for the issue, the epic created for it, and the epic work item' do
      pipeline.run

      imported_issue = project.issues.first
      epic = group.epics.find_by!(title: 'An epic')

      user_references = placeholder_user_references(::Import::SOURCE_DIRECT_TRANSFER, bulk_import.id)

      expect(user_references).to include(
        ['Issue', imported_issue.id, 'author_id', source_user.id],
        ['Epic', epic.id, 'author_id', source_user.id],
        ['WorkItem', epic.issue_id, 'author_id', source_user.id]
      )
    end

    context 'when epic_issue creation fails' do
      it 'creates issue but no epic_issue when ParentLinks::CreateService fails' do
        allow_next_instance_of(::WorkItems::ParentLinks::CreateService) do |service|
          allow(service).to receive(:execute).and_return({ status: :error, message: 'Service failed' })
        end

        expect { pipeline.run }.to change { Issue.count }.by(2)
                               .and not_change { EpicIssue.count }

        issue = project.issues.first
        expect(issue.epic_issue).to be_nil
      end

      it 'creates issue but no epic_issue when parent link creation returns empty references' do
        allow_next_instance_of(::WorkItems::ParentLinks::CreateService) do |service|
          allow(service).to receive(:execute).and_return({ status: :success, created_references: [] })
        end

        expect { pipeline.run }.to change { Issue.count }.by(2)
                               .and not_change { EpicIssue.count }

        issue = project.issues.first
        expect(issue.epic_issue).to be_nil
      end
    end

    context 'without epic association' do
      let(:issue_without_epic) do
        {
          'title' => 'title without epic',
          'state' => 'opened',
          'author_id' => 22
          # No epic_issue
        }
      end

      before do
        issue_with_index = [issue_without_epic, 0]
        allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
          allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [issue_with_index]))
        end
      end

      it 'creates issue normally using standard pipeline' do
        expect { pipeline.run }.to change { Issue.count }.by(1)
                               .and not_change { EpicIssue.count }
                               .and not_change { Epic.count }

        issue = project.issues.first
        expect(issue.epic_issue).to be_nil
        expect(issue.title).to eq('title without epic')
      end
    end
  end
end
