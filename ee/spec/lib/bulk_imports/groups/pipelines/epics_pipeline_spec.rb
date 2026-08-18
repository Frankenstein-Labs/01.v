# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Groups::Pipelines::EpicsPipeline, feature_category: :importers do
  include Import::UserMappingHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:another_user) { create(:user) }
  let_it_be(:group) { create(:group, owners: user) }
  let_it_be_with_reload(:bulk_import) { create(:bulk_import, :with_configuration, user: user) }
  let_it_be(:filepath) { 'ee/spec/fixtures/bulk_imports/gz/epics.ndjson.gz' }
  let_it_be_with_reload(:entity) do
    create(
      :bulk_import_entity,
      group: group,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path',
      destination_slug: 'My-Destination-Group',
      destination_namespace: group.full_path
    )
  end

  let_it_be_with_reload(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let_it_be_with_reload(:context) { BulkImports::Pipeline::Context.new(tracker) }

  let(:tmpdir) { Dir.mktmpdir }
  let(:licensed_epics) { true }
  let(:licensed_subepics) { true }
  let(:importer_user_mapping_enabled) { false }

  before do
    FileUtils.copy_file(filepath, File.join(tmpdir, 'epics.ndjson.gz'))
    stub_licensed_features(epics: licensed_epics, subepics: licensed_subepics)

    allow(context).to receive(:importer_user_mapping_enabled?).and_return(importer_user_mapping_enabled)
    allow(Import::PlaceholderReferences::PushService).to receive(:from_record).and_call_original
  end

  subject(:pipeline) { described_class.new(context) }

  shared_examples 'successfully imports' do
    it 'imports group epics into destination group' do
      pipeline.run
      group.reload

      expect(group.epics.count).to eq(6)
      expect(group.work_items.count).to eq(6)
      expect(WorkItems::ParentLink.count).to eq(4)
      expect(Epic.where.not(parent_id: nil).where.not(work_item_parent_link_id: nil).count).to eq(4)
      expect(Note.where(noteable_id: group.work_items.ids).count).to eq(9)
      expect(Note.where(imported_from: "none").count).to eq(0)
      expect(Note.count).to eq(9)

      group.epics.each do |epic|
        expect(epic.work_item).not_to be_nil

        if epic.work_item.parent_link.present?
          expect(epic.relative_position).to eq(epic.work_item.parent_link.relative_position)
        end

        diff = Gitlab::EpicWorkItemSync::Diff.new(epic, epic.work_item, strict_equal: true)
        expect(diff.attributes).to be_empty
      end
    end
  end

  describe '#run', :clean_gitlab_redis_shared_state, :aggregate_failures do
    before do
      allow(Dir).to receive(:mktmpdir).and_return(tmpdir)
      allow_next_instance_of(BulkImports::FileDownloadService) do |service|
        allow(service).to receive(:execute)
      end

      allow(pipeline).to receive(:set_source_objects_counter)
    end

    context 'when epic work item is created along epic object' do
      it_behaves_like 'successfully imports'

      context 'when epics are licensed but not subepics' do
        let(:licensed_epics) { true }
        let(:licensed_subepics) { false }

        it_behaves_like 'successfully imports'
      end

      context 'when neither epics or subepics are licensed' do
        let(:licensed_epics) { false }
        let(:licensed_subepics) { false }

        it_behaves_like 'successfully imports'
      end

      it 'imports correct epic author' do
        # map the original epic author to a user in the DB other than the one running the pipeline
        ::BulkImports::UsersMapper.new(context: context).cache_source_user_id(1, another_user.id)

        pipeline.run

        expect(group.epics.first.author_id).to eq(another_user.id)
      end

      it 'imports epic award emoji' do
        pipeline.run

        expect(group.epics.first.award_emoji.first.name).to eq('thumbsup')
      end

      it 'imports epic notes' do
        pipeline.run

        expect(group.epics.first.state).to eq('opened')
        expect(group.epics.first.notes.count).to eq(4)
        expect(group.epics.first.notes.first.award_emoji.first.name).to eq('drum')
      end

      it 'imports epic labels' do
        pipeline.run

        label = group.epics.first.labels.first

        expect(group.epics.first.labels.count).to eq(1)
        expect(label.title).to eq('title')
        expect(label.description).to eq('description')
        expect(label.color).to be_color('#cd2c5c')
      end

      it 'imports epic system note metadata' do
        pipeline.run

        note = group.epics.find_by_title('system notes').notes.first

        expect(note.system).to be(true)
        expect(note.system_note_metadata.action).to eq('relate_epic')
      end
    end

    # ObjectBuilder caches the Epic it builds for a nested `parent` relation, but only while
    # Gitlab::SafeRequestStore is active -- true in Sidekiq, false in specs unless :request_store
    # is set. Without it these examples pass even when the parent is created twice.
    context 'when sub-epics share a parent epic that is not imported first', :request_store do
      using RSpec::Parameterized::TableSyntax

      # Each entry is built separately so the two children hold equal but distinct parent hashes,
      # the way they arrive when each ndjson line is deserialized on its own.
      def epic_hash(iid:, title:, parent: nil)
        {
          'iid' => iid,
          'author_id' => 1,
          'title' => title,
          'description' => "#{title} description",
          'state' => 'opened'
        }.tap { |hash| hash['parent'] = parent if parent }
      end

      def parent_epic_hash
        epic_hash(iid: 1, title: 'Parent epic')
      end

      where(:case_name, :parent_has_own_line) do
        'the parent epic has no line of its own'    | false
        'the parent epic line comes after children' | true
      end

      with_them do
        let(:entries) do
          entries = [
            epic_hash(iid: 2, title: 'Child A', parent: parent_epic_hash),
            epic_hash(iid: 3, title: 'Child B', parent: parent_epic_hash)
          ]

          entries << parent_epic_hash if parent_has_own_line
          entries
        end

        before do
          extracted_data = BulkImports::Pipeline::ExtractedData.new(data: entries.each_with_index.to_a)

          allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
            allow(extractor).to receive(:extract).and_return(extracted_data)
          end
        end

        it 'creates the shared parent epic only once' do
          pipeline.run

          failures = entity.failures.map { |failure| "#{failure.exception_class}: #{failure.exception_message}" }

          expect(failures).to be_empty
          expect(group.work_items.count).to eq(3)
          expect(WorkItems::ParentLink.count).to eq(2)
        end
      end
    end

    context 'when importer_user_mapping is enabled' do
      let_it_be(:source_user) do
        create(:import_source_user,
          import_type: ::Import::SOURCE_DIRECT_TRANSFER,
          namespace: group,
          source_user_identifier: 101,
          source_hostname: bulk_import.configuration.url,
          placeholder_user: create(:user, :import_user)
        )
      end

      let(:importer_user_mapping_enabled) { true }

      let(:epic) do
        {
          author_id: 101,
          iid: 2,
          updated_by_id: 101,
          last_edited_by_id: 101,
          assignee_id: 101,
          last_edited_at: '2019-11-20T17:02:09.812Z',
          title: 'Child epic',
          description: 'Child epic description',
          state_id: 'opened',
          notes: [
            {
              note: 'some system note 1',
              noteable_type: 'Epic',
              author_id: 101,
              system: true
            },
            {
              note: 'some system note 2',
              noteable_type: 'Issue',
              author_id: 101,
              system: true
            }
          ],
          label_links: [
            {
              target_type: 'Epic',
              label: {
                title: 'label1 title',
                type: 'GroupLabel'
              }
            },
            {
              target_type: 'Issue',
              label: {
                title: 'label2 title',
                type: 'GroupLabel'
              }
            }
          ],
          award_emoji: [
            {
              name: 'thumbsdown',
              user_id: 101,
              awardable_type: 'Epic'
            },
            {
              name: 'thumbsup',
              user_id: 101,
              awardable_type: 'Issue'
            }
          ]
        }.deep_stringify_keys
      end

      before do
        allow_next_instance_of(BulkImports::Common::Extractors::NdjsonExtractor) do |extractor|
          allow(extractor).to receive(:remove_tmp_dir)
          allow(extractor).to receive(:extract).and_return(BulkImports::Pipeline::ExtractedData.new(data: [[epic, 0]]))
        end
      end

      it 'imports epics and maps user references to placeholder users', :aggregate_failures do
        pipeline.run

        epic = group.reload.epics.last

        work_item = epic.issue
        notes = epic.notes
        award_emoji = epic.award_emoji
        label_links = epic.label_links
        labels = epic.labels

        expect(notes.map(&:note)).to match_array(['some system note 1', 'some system note 2'])
        expect(notes.map(&:noteable_type)).to match_array(%w[Issue Issue])

        expect(award_emoji.map(&:name)).to match_array(%w[thumbsup thumbsdown])
        expect(award_emoji.map(&:awardable_type)).to match_array(%w[Issue Issue])

        expect(label_links.map(&:label_id)).to match_array(epic.labels.map(&:id))
        expect(label_links.map(&:target_type)).to match_array(%w[Issue Issue])

        expect(labels.map(&:title)).to match_array(['label1 title', 'label2 title'])

        source_user = Import::SourceUser.find_by(source_user_identifier: 101)
        expect(source_user.placeholder_user).to eq(epic.author)

        expect(epic.author).to be_import_user
        expect(epic.last_edited_by).to be_import_user
        expect(epic.updated_by).to be_import_user
        expect(epic.assignee_id).to be_nil
        expect(work_item.author).to be_import_user
        expect(work_item.last_edited_by).to be_import_user
        expect(work_item.updated_by).to be_import_user
        expect(notes.first.author).to be_import_user
        expect(award_emoji.first.user).to be_import_user

        user_references = placeholder_user_references(::Import::SOURCE_DIRECT_TRANSFER, bulk_import.id)

        expect(user_references).to match_array([
          ['Epic', epic.id, 'author_id', source_user.id],
          ['Epic', epic.id, 'last_edited_by_id', source_user.id],
          ['Epic', epic.id, 'updated_by_id', source_user.id],
          ['WorkItem', work_item.id, 'author_id', source_user.id],
          ['WorkItem', work_item.id, 'last_edited_by_id', source_user.id],
          ['WorkItem', work_item.id, 'updated_by_id', source_user.id],
          ['Note', notes.first.id, 'author_id', source_user.id],
          ['Note', notes.second.id, 'author_id', source_user.id],
          ['AwardEmoji', award_emoji.first.id, 'user_id', source_user.id],
          ['AwardEmoji', award_emoji.second.id, 'user_id', source_user.id]
        ])
      end

      context 'when importing epics has a parent epic' do
        let_it_be(:other_source_user) do
          create(:import_source_user,
            import_type: ::Import::SOURCE_DIRECT_TRANSFER,
            namespace: group,
            source_user_identifier: 102,
            source_hostname: bulk_import.configuration.url,
            placeholder_user: create(:user, :import_user)
          )
        end

        let(:epic) do
          {
            "author_id" => 102,
            "iid" => 2,
            "updated_by_id" => 102,
            "title" => "Child epic",
            "closed_by_id" => 102,
            "last_edited_by_id" => 102,
            "state" => "opened",
            "parent" => {
              "author_id" => 101,
              "iid" => 1,
              "updated_by_id" => 101,
              "last_edited_by_id" => 101,
              "title" => "Parent epic",
              "closed_by_id" => 101
            }
          }
        end

        # Epic rows and their work items must both be referenced. WorkItems::SyncAsEpic only syncs
        # WorkItem -> Epic, and reassignment uses `update_all`, so an epic reference without the
        # matching work item reference leaves the two records pointing at different users.
        it 'pushes placeholder references for the child epic, the parent created alongside it, ' \
          'and both work items' do
          pipeline.run

          parent_epic, child_epic = group.reload.epics.order(:id).to_a

          user_references = placeholder_user_references(::Import::SOURCE_DIRECT_TRANSFER, bulk_import.id)

          expect(user_references).to match_array([
            ['Epic', child_epic.id, 'author_id', other_source_user.id],
            ['Epic', child_epic.id, 'last_edited_by_id', other_source_user.id],
            ['Epic', child_epic.id, 'updated_by_id', other_source_user.id],
            ['Epic', child_epic.id, 'closed_by_id', other_source_user.id],
            ['WorkItem', child_epic.issue_id, 'author_id', other_source_user.id],
            ['WorkItem', child_epic.issue_id, 'last_edited_by_id', other_source_user.id],
            ['WorkItem', child_epic.issue_id, 'updated_by_id', other_source_user.id],
            ['WorkItem', child_epic.issue_id, 'closed_by_id', other_source_user.id],
            ['Epic', parent_epic.id, 'author_id', source_user.id],
            ['Epic', parent_epic.id, 'last_edited_by_id', source_user.id],
            ['Epic', parent_epic.id, 'updated_by_id', source_user.id],
            ['Epic', parent_epic.id, 'closed_by_id', source_user.id],
            ['WorkItem', parent_epic.issue_id, 'author_id', source_user.id],
            ['WorkItem', parent_epic.issue_id, 'last_edited_by_id', source_user.id],
            ['WorkItem', parent_epic.issue_id, 'updated_by_id', source_user.id],
            ['WorkItem', parent_epic.issue_id, 'closed_by_id', source_user.id]
          ])
        end
      end

      context 'when direct reassignment is supported' do
        before do
          allow(Import::DirectReassignService).to receive(:supported?).and_return(true)
        end

        it 'does not push any placeholder references' do
          pipeline.run

          expect(Import::PlaceholderReferences::PushService).not_to have_received(:from_record)
        end
      end
    end
  end

  describe '#load' do
    context 'when epic is missing' do
      it 'returns' do
        expect(subject.load(context, nil)).to be_nil
      end
    end
  end

  describe 'pipeline parts' do
    it { expect(described_class).to include_module(BulkImports::NdjsonPipeline) }
    it { expect(described_class).to include_module(BulkImports::Pipeline::Runner) }

    it 'has extractor' do
      expect(described_class.get_extractor)
        .to eq(
          klass: BulkImports::Common::Extractors::NdjsonExtractor,
          options: { relation: described_class.relation }
        )
    end
  end
end
