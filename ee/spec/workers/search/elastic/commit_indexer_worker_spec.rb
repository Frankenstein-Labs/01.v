# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::CommitIndexerWorker, feature_category: :global_search do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:project, freeze: false) { create(:project, :repository) }
  let(:logger_double) { instance_double(Gitlab::Elasticsearch::Logger) }

  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      stub_ee_application_setting(elasticsearch_indexing: true)
    end

    it 'runs indexer' do
      expect_next_instance_of(Search::Elastic::Indexer) do |indexer|
        expect(indexer).to receive(:run)
      end

      worker.perform(project.id)
    end

    context 'when the project does not exist' do
      let_it_be(:id) { non_existing_record_id }
      let_it_be(:es_id) do
        Search::Elastic::Helper.build_es_id(es_type: Project.es_type, target_id: non_existing_record_id)
      end

      it 'calls ElasticDeleteProjectWorker on the project to delete all documents and returns true' do
        expect(ElasticDeleteProjectWorker).to receive(:perform_async).with(id, es_id, 'delete_project' => true)
        expect(Search::Elastic::Indexer).not_to receive(:new)
        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
        expect(worker.perform(id)).to be true
      end
    end

    context 'when elasticsearch is disabled for Project' do
      it 'calls ElasticDeleteProjectWorker to keep itself and only delete associated documents and returns true' do
        allow_next_found_instance_of(Project) do |project|
          expect(project).to receive(:use_elasticsearch?).and_return(false)
        end
        expect(ElasticDeleteProjectWorker).to receive(:perform_async)
          .with(project.id, project.es_id, 'delete_project' => false)
        expect(Search::Elastic::Indexer).not_to receive(:new)
        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)
        expect(worker.perform(project.id)).to be true
      end
    end

    it 'logs timing information' do
      allow_next_instance_of(Search::Elastic::Indexer) do |indexer|
        allow(indexer).to receive(:run).and_return(true)
      end

      expect(Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger_double.as_null_object)

      expect(logger_double).to receive(:info).with(
        project_id: project.id,
        search_indexing_duration_s: an_instance_of(Float),
        jid: anything
      )

      worker.perform(project.id)
    end

    it 'records the apdex SLI' do
      allow_next_instance_of(Search::Elastic::Indexer) do |indexer|
        allow(indexer).to receive(:run).and_return(true)
      end

      expect(Gitlab::Metrics::GlobalSearchIndexingSlis).to receive(:record_apdex).with(
        elapsed: a_kind_of(Numeric),
        document_type: 'Code'
      )

      worker.perform(project.id)
    end

    context 'when force is not set' do
      before do
        allow_next_instance_of(Search::Elastic::Indexer) do |indexer|
          allow(indexer).to receive(:run).and_return(true)
        end
      end

      it 'does not log extra metadata on done' do
        expect(worker).not_to receive(:log_extra_metadata_on_done)

        worker.perform(project.id)
      end
    end

    context 'when force is set' do
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:stats, freeze: false) do
        create(:project_statistics, with_data: true, project: project, commit_count: 10)
      end

      before do
        allow_next_instance_of(Search::Elastic::Indexer) do |indexer|
          allow(indexer).to receive(:run).and_return(true)
        end
      end

      it 'logs extra metadata on done when run', :aggregate_failures do
        expect(worker).to receive(:log_extra_metadata_on_done).with(:commit_count, 10)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:repository_size, 1)

        worker.perform(project.id, { 'force' => true })
      end
    end

    context 'when ES is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'returns true' do
        expect(Search::Elastic::Indexer).not_to receive(:new)

        expect(worker.perform(project.id)).to be_truthy
      end

      it 'does not log anything' do
        expect(logger_double).not_to receive(:info)

        worker.perform(project.id)
      end

      it 'does not record the apdex SLI' do
        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)

        worker.perform(project.id)
      end
    end

    it 'runs indexer with the correct parameters' do
      indexer = double

      expect(indexer).to receive(:run)
      expect(Search::Elastic::Indexer).to receive(:new).with(project, force: false).and_return(indexer)

      worker.perform(project.id)
    end

    context 'when the indexer is locked' do
      it 'does not run index' do
        expect(worker).to receive(:in_lock) # Mock and don't yield
          .with("Search::Elastic::CommitIndexerWorker/#{project.id}",
            ttl: Search::Elastic::Indexer.timeout + 1.minute,
            retries: 2,
            sleep_sec: 1)

        expect(Search::Elastic::Indexer).not_to receive(:new)

        worker.perform(project.id)
      end

      it 'does not log anything' do
        expect(worker).to receive(:in_lock) # Mock and don't yield
          .with("Search::Elastic::CommitIndexerWorker/#{project.id}",
            ttl: Search::Elastic::Indexer.timeout + 1.minute,
            retries: 2,
            sleep_sec: 1)

        expect(logger_double).not_to receive(:info)

        worker.perform(project.id)
      end

      it 'does not record the apdex SLI' do
        expect(worker).to receive(:in_lock) # Mock and don't yield
          .with("Search::Elastic::CommitIndexerWorker/#{project.id}",
            ttl: Search::Elastic::Indexer.timeout + 1.minute,
            retries: 2,
            sleep_sec: 1)

        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)

        worker.perform(project.id)
      end

      it 'does not log extra metadata' do
        expect(worker).to receive(:in_lock) # Mock and don't yield
          .with("Search::Elastic::CommitIndexerWorker/#{project.id}",
            ttl: Search::Elastic::Indexer.timeout + 1.minute,
            retries: 2,
            sleep_sec: 1)

        expect(worker).not_to receive(:log_extra_metadata_on_done)

        worker.perform(project.id)
      end

      it 'skips index and schedules a job' do
        expect(worker).to receive(:in_lock)
          .with("Search::Elastic::CommitIndexerWorker/#{project.id}",
            ttl: Search::Elastic::Indexer.timeout + 1.minute,
            retries: 2,
            sleep_sec: 1)
          .and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)

        expect(Search::Elastic::Indexer).not_to receive(:new)
        expect(described_class).to receive(:perform_in)
          .with(described_class::RETRY_IN_IF_LOCKED, project.id, {})

        worker.perform(project.id)
      end
    end

    context 'when the indexer fails' do
      it 'does not log anything' do
        expect_next_instance_of(Search::Elastic::Indexer) do |indexer|
          expect(indexer).to receive(:run).and_return false
        end

        expect(logger_double).not_to receive(:info)

        worker.perform(project.id)
      end

      it 'does not record the apdex SLI' do
        expect_next_instance_of(Search::Elastic::Indexer) do |indexer|
          expect(indexer).to receive(:run).and_return false
        end

        expect(Gitlab::Metrics::GlobalSearchIndexingSlis).not_to receive(:record_apdex)

        worker.perform(project.id)
      end

      it 'does not log extra metadata' do
        expect_next_instance_of(Search::Elastic::Indexer) do |indexer|
          expect(indexer).to receive(:run).and_return false
        end

        expect(worker).not_to receive(:log_extra_metadata_on_done)

        worker.perform(project.id)
      end
    end
  end

  it 'registers worker to limit concurrency' do
    stub_application_setting(elasticsearch_max_code_indexing_concurrency: 35)

    max_jobs = described_class.get_concurrency_limit
    expect(max_jobs).to eq(35)
  end
end
