# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::ProcessBookkeepingService,
  :clean_gitlab_redis_shared_state,
  :elastic,
  feature_category: :global_search do
  include ProjectForksHelper
  let(:ref_class) { ::Search::Elastic::DocumentReference }

  let(:fake_refs) { Array.new(10) { |i| ref_class.new(Issue, i, "issue_#{i}", 'project_1') } }
  let(:issue) { fake_refs.first }
  let(:issue_spec) { issue.serialize }

  before do
    stub_ee_application_setting(elasticsearch_worker_number_of_shards: described_class::SHARDS_MAX)
  end

  describe '.active_number_of_shards' do
    using RSpec::Parameterized::TableSyntax

    where(:worker_number_of_shards, :result) do
      0  | 1
      2  | 2
      20 | 16
      15 | 15
    end

    with_them do
      before do
        stub_ee_application_setting(elasticsearch_worker_number_of_shards: worker_number_of_shards)
      end

      it 'returns smaller number' do
        expect(described_class.active_number_of_shards).to eq(result)
      end
    end
  end

  describe '.shard_number' do
    it 'returns correct shard number' do
      shard = described_class.shard_number(ref_class.serialize(fake_refs.first))

      expect(shard).to eq(9)
    end

    it 'returns correct shard number when number_of_shards has been changed' do
      stub_ee_application_setting(elasticsearch_worker_number_of_shards: 2)

      shard = described_class.shard_number(ref_class.serialize(fake_refs.first))

      expect(shard).to eq(1)
    end
  end

  describe '.track' do
    it 'enqueues a record' do
      described_class.track!(issue)

      shard = described_class.shard_number(issue_spec)

      spec, score = described_class.queued_items[shard].first

      expect(spec).to eq(issue_spec)
      expect(score).to eq(1.0)
    end

    it 'enqueues a set of unique records' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)
      expect(described_class.queued_items.keys).to contain_exactly(0, 1, 3, 4, 6, 8, 9, 10, 13)
    end

    it 'orders items based on when they were added and moves them to the back of the queue if they were added again' do
      shard_number = 9
      item1_in_shard = ref_class.new(Issue, 0, 'issue_0', 'project_1')
      item2_in_shard = ref_class.new(Issue, 8, 'issue_8', 'project_1')

      described_class.track!(item1_in_shard)
      described_class.track!(item2_in_shard)

      expect(described_class.queued_items[shard_number][0]).to eq([item1_in_shard.serialize, 1.0])
      expect(described_class.queued_items[shard_number][1]).to eq([item2_in_shard.serialize, 2.0])

      described_class.track!(item1_in_shard)

      expect(described_class.queued_items[shard_number][0]).to eq([item2_in_shard.serialize, 2.0])
      expect(described_class.queued_items[shard_number][1]).to eq([item1_in_shard.serialize, 3.0])
    end

    it 'enqueues 10 identical records as 1 entry' do
      described_class.track!(*([issue] * 10))

      expect(described_class.queue_size).to eq(1)
    end

    it 'deduplicates across multiple inserts' do
      10.times { described_class.track!(issue) }

      expect(described_class.queue_size).to eq(1)
    end

    it 'serializes with Elastic::Reference' do
      expect(::Search::Elastic::Reference).to receive(:serialize).with(issue).and_call_original

      described_class.track!(issue)
    end

    it 'flattens array references from multi-index models' do
      ref1 = 'Vulnerability|1|group_1'
      ref2 = 'Vulnerabilities::Read|1|group_1'
      allow(::Search::Elastic::Reference).to receive(:serialize).and_return([ref1, ref2])

      described_class.track!(issue)

      expect(described_class.queue_size).to eq(2)
    end
  end

  describe '.queue_size' do
    it 'reports the queue size' do
      expect(described_class.queue_size).to eq(0)

      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)
    end
  end

  describe '.queued_items' do
    it 'reports queued items' do
      expect(described_class.queued_items).to be_empty

      described_class.track!(*fake_refs.take(3))

      expect(described_class.queued_items).to eq(
        4 => [["Issue 1 issue_1 project_1", 1.0]],
        6 => [["Issue 2 issue_2 project_1", 1.0]],
        9 => [["Issue 0 issue_0 project_1", 1.0]]
      )
    end
  end

  describe '.clear_tracking!' do
    it 'removes all entries from the queue' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)

      described_class.clear_tracking!

      expect(described_class.queue_size).to eq(0)
    end
  end

  describe '.maintain_indexed_associations' do
    let(:project) { create(:project) }

    it 'calls track! for each associated object' do
      issue_1 = create(:issue, project: project)
      issue_2 = create(:issue, project: project)
      merge_request1 = create(:merge_request, source_project: project, target_project: project)

      expect(described_class).to receive(:track!).with(issue_1, issue_2).ordered
      expect(described_class).to receive(:track!).with(merge_request1).ordered

      described_class.maintain_indexed_associations(project, %w[issues merge_requests])
    end

    it 'correctly scopes associated note objects to not include system notes' do
      note_searchable = create(:note, :on_issue, project: project)
      create(:note, :on_issue, :system, project: project)

      expect(described_class).to receive(:track!).with(note_searchable)

      described_class.maintain_indexed_associations(project, ['notes'])
    end

    it 'correctly scopes associated issue objects to not include issues nil project_id' do
      author = create(:user)
      issue_searchable = create(:issue, project: project, author: author)
      create(:issue, :with_synced_epic, author: author)

      expect(described_class).to receive(:track!).with(issue_searchable)

      described_class.maintain_indexed_associations(author, ['issues'])
    end
  end

  describe '.maintain_indexed_namespace_associations' do
    let_it_be(:group) { create(:group) }
    let_it_be(:epic) { create(:epic, group: group) }

    it 'does not call ElasticAssociationIndexerWorker' do
      expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)

      described_class.maintain_indexed_namespace_associations!(group)
    end

    it 'does not call ElasticAssociationIndexerWorker for projects' do
      expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)

      described_class.maintain_indexed_namespace_associations!(create(:project))
    end

    context 'if the group is use_elasticsearch?' do
      before do
        allow(group).to receive(:use_elasticsearch?).and_return(true)
      end

      it 'calls ElasticAssociationIndexerWorker' do
        expect(ElasticAssociationIndexerWorker).to receive(:perform_async)
          .with("Group", group.id, %w[epics work_items])

        described_class.maintain_indexed_namespace_associations!(group)
      end
    end

    context 'if the group is not use_elasticsearch?' do
      before do
        allow(group).to receive(:use_elasticsearch?).and_return(false)
      end

      it 'does not call ElasticAssociationIndexerWorker' do
        expect(ElasticAssociationIndexerWorker).not_to receive(:perform_async)

        described_class.maintain_indexed_namespace_associations!(group)
      end
    end
  end

  describe '#execute' do
    context 'when limit is less than refs count' do
      before do
        stub_const('Elastic::ProcessBookkeepingService::SHARD_LIMIT', 2)
        stub_const('Elastic::ProcessBookkeepingService::SHARDS_MAX', 2)
      end

      it 'processes only up to limit' do
        described_class.track!(*fake_refs)

        expect(described_class.queue_size).to eq(fake_refs.size)
        allow_processing(*fake_refs)

        expect { described_class.new.execute }.to change { described_class.queue_size }.by(-4)
      end

      context 'when limited to one shard' do
        let(:shard_number) { 1 }

        it 'only processes specified shard' do
          described_class.track!(*fake_refs)

          expect(described_class.queue_size).to eq(fake_refs.size)
          allow_processing(*fake_refs)

          refs_in_shard = described_class.queued_items[shard_number]
          expect { described_class.new.execute(shards: [shard_number]) }.to change { described_class.queue_size }
                                                                        .by(-refs_in_shard.count)
        end
      end
    end

    it 'submits a batch of documents' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)
      expect_processing(*fake_refs)

      expect { described_class.new.execute }.to change { described_class.queue_size }.by(-fake_refs.count)
    end

    it 'returns the number of documents processed and number of failures' do
      described_class.track!(*fake_refs)
      failed = fake_refs[0]

      expect_processing(*fake_refs, failures: [failed])

      expect(described_class.new.execute).to eq([fake_refs.count, 1])
    end

    it 'returns 0 docments processed and 0 failures without writing to the index when there are no documents' do
      expect(::Search::Elastic::BulkIndexer).not_to receive(:new)

      expect(described_class.new.execute).to eq([0, 0])
    end

    it 'routes failed documents to retry queue' do
      described_class.track!(*fake_refs)
      failed = fake_refs[0]

      expect(described_class.queue_size).to eq(10)
      expect(Search::Elastic::RetryQueue.queue_size).to eq(0)
      expect_processing(*fake_refs, failures: [failed])

      expect { described_class.new.execute }.to change { described_class.queue_size }.by(-fake_refs.count)

      expect(Search::Elastic::RetryQueue.queue_size).to eq(1)

      shard = Search::Elastic::RetryQueue.shard_number(failed.serialize)
      serialized = Search::Elastic::RetryQueue.queued_items[shard].first[0]

      expect(ref_class.deserialize(serialized)).to eq(failed)
    end

    it 'discards malformed documents' do
      described_class.track!('Bad')

      expect(described_class.queue_size).to eq(1)
      expect_next_instance_of(::Search::Elastic::BulkIndexer) do |indexer|
        expect(indexer).not_to receive(:process)
      end

      expect { described_class.new.execute }.to change { described_class.queue_size }.by(-1)
    end

    it 'fails, preserving documents, when processing fails with an exception' do
      described_class.track!(issue)

      expect(described_class.queue_size).to eq(1)
      expect_next_instance_of(::Search::Elastic::BulkIndexer) do |indexer|
        expect(indexer).to receive(:process).with(issue) { raise 'Bad' }
      end

      expect { described_class.new.execute }.to raise_error('Bad')
      expect(described_class.queue_size).to eq(1)
    end

    it 'deserializes and processes each tracked item' do
      issue_2 = create(:issue)
      described_class.track!(issue, issue_2)

      expect(Search::Elastic::Reference).to receive(:deserialize).with(issue_2.elastic_reference).and_call_original
      expect(Search::Elastic::Reference).to receive(:deserialize).with(issue_spec).and_call_original
      expect(Search::Elastic::Reference).to receive(:preload_database_records).and_call_original

      expect_next_instance_of(::Search::Elastic::BulkIndexer) do |indexer|
        expect(indexer).to receive(:process).twice.and_call_original
      end

      described_class.new.execute
    end

    context 'for logging' do
      let(:logger_double) { instance_double(Gitlab::Elasticsearch::Logger) }

      before do
        allow(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)
      end

      it 'logs the time it takes to flush the bulk indexer' do
        described_class.track!(*fake_refs)
        expect_processing(*fake_refs)

        expect(logger_double).to receive(:info).with(
          'class' => described_class.name,
          'message' => 'bulk_indexer_flushed',
          'meta.indexing.search_flushing_duration_s' => an_instance_of(Float),
          'meta.indexing.search_indexed_bytes_per_second' => an_instance_of(Integer)
        )

        described_class.new.execute
      end

      it 'logs model information and indexing duration about each successful indexing' do
        described_class.track!(*fake_refs)
        expect_processing(*fake_refs)

        expect(logger_double).to receive(:info).with(
          'class' => described_class.name,
          'message' => 'indexing_done',
          'meta.indexing.reference_class' => "Issue",
          'meta.indexing.database_id' => an_instance_of(String),
          'meta.indexing.identifier' => an_instance_of(String),
          'meta.indexing.routing' => "project_1",
          'meta.indexing.search_indexing_duration_s' => an_instance_of(Float),
          'meta.indexing.search_indexing_flushing_duration_s' => an_instance_of(Float)
        ).exactly(fake_refs.size).times

        described_class.new.execute
      end

      it 'logs when a document fails to be deserialized' do
        described_class.track!(*fake_refs)

        allow(Search::Elastic::Reference).to receive(:deserialize).and_raise(Search::Elastic::Reference::InvalidError)

        expect(logger_double).to receive(:error)
          .with(hash_including('message' => 'submit_document_failed'))
          .exactly(fake_refs.size).times

        described_class.new.execute
      end

      it 'does not log about failed indexing' do
        described_class.track!(*fake_refs)

        failed = fake_refs[0]
        expect_processing(*fake_refs, failures: [failed])

        expect(logger_double).not_to receive(:info).with(
          'class' => described_class.name,
          'message' => 'indexing_done',
          'meta.indexing.reference_class' => "Issue",
          'meta.indexing.database_id' => failed.db_id,
          'meta.indexing.identifier' => failed.es_id,
          'meta.indexing.routing' => "project_1",
          'meta.indexing.search_indexing_duration_s' => an_instance_of(Float),
          'meta.indexing.search_indexing_flushing_duration_s' => an_instance_of(Float)
        )

        expect(logger_double).to receive(:info).with(
          'class' => described_class.name,
          'message' => 'indexing_done',
          'meta.indexing.reference_class' => "Issue",
          'meta.indexing.database_id' => an_instance_of(String),
          'meta.indexing.identifier' => an_instance_of(String),
          'meta.indexing.routing' => "project_1",
          'meta.indexing.search_indexing_duration_s' => an_instance_of(Float),
          'meta.indexing.search_indexing_flushing_duration_s' => an_instance_of(Float)
        ).exactly(fake_refs.size - 1).times

        described_class.new.execute
      end

      it 'increments the custom indexing sli apdex' do
        described_class.track!(*fake_refs)
        expect_processing(*fake_refs)

        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_bytes_per_second_apdex).with(
          throughput: a_kind_of(Numeric),
          target: Gitlab::Metrics::GlobalSearchIndexingSlis::INCREMENTAL_INDEXED_BYTES_PER_SECOND_TARGET
        ).once

        described_class.new.execute
      end

      it 'does not increment the custom indexing sli apdex for failed indexing' do
        described_class.track!(*fake_refs)

        failed = fake_refs[0]
        expect_processing(*fake_refs, failures: [failed])

        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_bytes_per_second_apdex).with(
          throughput: a_kind_of(Numeric),
          target: Gitlab::Metrics::GlobalSearchIndexingSlis::INCREMENTAL_INDEXED_BYTES_PER_SECOND_TARGET
        ).once

        described_class.new.execute
      end
    end

    context 'for N+1 queries' do
      it 'does not have N+1 queries for projects' do
        project = create(:project)
        projects = [create(:project, group: create(:group))]
        projects << fork_project(project)
        projects << create(:project, :mirror)

        described_class.track!(*projects)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

        projects << create(:project, group: create(:group))
        projects << fork_project(project)
        projects << create(:project, :mirror)

        described_class.track!(*projects)

        expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
      end

      it 'does not have N+1 queries for groups' do
        parent_group = create(:group)
        organization = create(:organization)
        groups = [create(:group)]
        groups << create(:group, parent: parent_group)
        groups << create(:group, organization: organization)

        groups.each { |group| group.namespace_settings.update!(archived: true) }

        described_class.track!(*groups)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

        parent_group2 = create(:group)
        organization2 = create(:organization)
        groups << create(:group)
        groups << create(:group, parent: parent_group2)
        groups << create(:group, organization: organization2)

        groups[-3..].each { |group| group.namespace_settings.update!(archived: true) }

        described_class.track!(*groups)

        expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
      end

      shared_examples 'efficient preloads for work_items' do
        it 'does not have N+1 queries for work_items', :request_store do
          group = create(:group)
          project = create(:project)
          parent_group = create(:group)
          nested_group = create(:group, parent: parent_group)
          work_items = [
            create(:work_item, project: project, milestone: create(:milestone, project: project)),
            create(:work_item, namespace: group, milestone: create(:milestone, group: group)),
            create(:work_item, namespace: nested_group, milestone: create(:milestone, group: nested_group))
          ]

          described_class.track!(*work_items)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

          group = create(:group)
          project = create(:project)
          parent_group = create(:group)
          nested_group = create(:group, parent: parent_group)
          work_items += [
            create(:work_item, project: project, milestone: create(:milestone, project: project)),
            create(:work_item, namespace: group, milestone: create(:milestone, group: group)),
            create(:work_item, namespace: nested_group, milestone: create(:milestone, group: nested_group))
          ]

          described_class.track!(*work_items)

          expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
        end

        it 'does not have N+1 queries for epics' do
          epics = create_list(:epic, 2, :use_fixed_dates)

          described_class.track!(*epics)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

          epics += create_list(:epic, 3, :use_fixed_dates)

          described_class.track!(*epics)

          # +6 from configurable work item types per new root namespace:
          # custom_types lookup (1) + work_item_settings lookup (1)
          expect do
            described_class.new.execute
          end.not_to exceed_all_query_limit(control).with_threshold(6)
        end

        it 'does not have N+1 queries for epics in a group with multiple parents', :request_store do
          parent_group = create(:group)
          group = create(:group, parent: parent_group)

          epics = create_list(:epic, 2, group: group)

          described_class.track!(*epics)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

          epics += create_list(:epic, 3, group: create(:group, parent: parent_group))

          described_class.track!(*epics)

          expect do
            described_class.new.execute
          end.not_to exceed_all_query_limit(control)
        end

        it 'does not have N+1 queries for epics with inherited dates' do
          child_epic = create(:epic, :use_fixed_dates)
          milestone = create(:milestone, :with_dates)

          epics = create_list(:epic, 2)
          epics.each do |epic|
            epic.start_date_sourcing_epic = child_epic
            epic.due_date_sourcing_milestone = milestone
            epic.save!
          end

          described_class.track!(*epics)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

          epics += create_list(:epic, 3)
          epics.each do |epic|
            epic.start_date_sourcing_epic = child_epic
            epic.due_date_sourcing_milestone = milestone
            epic.save!
          end

          described_class.track!(*epics)

          # +6 from configurable work item types per new root namespace:
          # custom_types lookup (1) + work_item_settings lookup (1) - no request store here
          expect do
            described_class.new.execute
          end.not_to exceed_all_query_limit(control).with_threshold(6)
        end
      end

      it_behaves_like 'efficient preloads for work_items'

      it 'does not have N+1 queries for notes' do
        # Gitaly N+1 calls when processing notes on commits
        # https://gitlab.com/gitlab-org/gitlab/-/issues/327086 . Even though
        # this block is in the spec there is still an N+1 to fix in the actual
        # code.
        Gitlab::GitalyClient.allow_n_plus_1_calls do
          notes = []

          2.times do
            notes << create(:note_on_issue)
            notes << create(:discussion_note_on_merge_request)
            notes << create(:note_on_merge_request)
            notes << create(:note_on_commit)
            notes << create(:diff_note_on_merge_request)
            notes << create(:note_on_epic)
            notes << create(:discussion_note_on_personal_snippet)
            notes << create(:note, :on_group_work_item)
          end

          described_class.track!(*notes)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

          3.times do
            notes << create(:note_on_issue)
            notes << create(:discussion_note_on_merge_request)
            notes << create(:note_on_merge_request)
            notes << create(:note_on_commit)
            notes << create(:diff_note_on_merge_request)
            notes << create(:note_on_epic)
            notes << create(:discussion_note_on_personal_snippet)
            notes << create(:note, :on_group_work_item)
          end

          described_class.track!(*notes)

          expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
        end
      end

      it 'does not have N+1 queries for issues', :request_store do
        issues = create_list(:issue, 2)

        described_class.track!(*issues)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

        issues += create_list(:issue, 3)

        described_class.track!(*issues)

        expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
      end

      it 'does not have N+1 queries for milestones' do
        milestones = create_list(:milestone, 2)

        described_class.track!(*milestones)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

        milestones += create_list(:milestone, 3)

        described_class.track!(*milestones)

        expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
      end

      it 'does not have N+1 queries for merge_requests' do
        merge_requests = create_list(:merge_request, 2, :with_assignee)

        described_class.track!(*merge_requests)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

        user = create(:user)
        merge_requests += create_list(:merge_request, 3, :with_assignee) do |mr|
          mr.assignee_ids << user.id
        end

        described_class.track!(*merge_requests)

        expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
      end

      it 'does not have N+1 queries for users' do
        users = create_list(:user, 2)

        described_class.track!(*users)

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

        users += create_list(:user, 3)

        described_class.track!(*users)

        expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
      end

      context 'when the user is a member of a project in a namespace with a parent group' do
        let_it_be(:parent_group) { create(:group) }
        let_it_be(:group) { create(:group, parent: parent_group) }
        let_it_be(:project) { create(:project, group: group) }

        it 'does not have N+1 queries for users' do
          users = create_list(:user, 2)
          users.each { |user| project.add_developer(user) }

          described_class.track!(*users)

          control = ActiveRecord::QueryRecorder.new(skip_cached: false) { described_class.new.execute }

          new_users = create_list(:user, 3)
          new_users.each { |user| project.add_developer(user) }

          users += new_users

          described_class.track!(*users)

          expect { described_class.new.execute }.not_to exceed_all_query_limit(control)
        end
      end
    end

    def expect_processing(*refs, failures: [])
      expect_next_instance_of(::Search::Elastic::BulkIndexer) do |indexer|
        refs.each { |ref| expect(indexer).to receive(:process).with(ref).and_return(10) }

        expect(indexer).to receive(:flush) { failures }
      end
    end

    def allow_processing(*refs, failures: [])
      expect_next_instance_of(::Search::Elastic::BulkIndexer) do |indexer|
        refs.each { |_ref| allow(indexer).to receive(:process).with(anything).and_return(10) }

        expect(indexer).to receive(:flush) { failures }
      end
    end
  end
end
