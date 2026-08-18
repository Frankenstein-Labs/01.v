# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::DeleteWorker, :elastic_helpers, feature_category: :global_search do
  describe '#perform' do
    subject(:perform) do
      described_class.new.perform({ task: :delete_project_associations })
    end

    it 'is a pause_control worker' do
      expect(described_class.get_pause_control).to eq(:advanced_search)
    end

    context 'when Elasticsearch is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'does not do anything' do
        expect(perform).to be_falsey
      end
    end

    context 'when Elasticsearch is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      context 'when we pass :all' do
        before do
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
        end

        it 'queues only project tasks' do
          described_class::PROJECT_TASKS.each_key do |t|
            expect(described_class).to receive(:perform_async).with(hash_including('task' => t.to_s))
          end
          expect(described_class).not_to receive(:perform_async).with(hash_including('task' => 'delete_all_blobs'))
          expect(described_class).not_to receive(:perform_async)
            .with(hash_including('task' => 'delete_tracked_context_sbom_occurrences'))
          described_class.new.perform({ task: :all })
        end

        context 'when a task has a migration_guard that has not finished' do
          before do
            allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
              .with(:create_vulnerability_reads_index).and_return(false)
            allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
              .with(:create_sbom_occurrence_refs_index).and_return(false)
          end

          it 'skips tasks whose migration guard has not finished' do
            expect(described_class).not_to receive(:perform_async)
              .with(hash_including('task' => 'delete_project_vulnerability_reads'))
            expect(described_class).not_to receive(:perform_async)
              .with(hash_including('task' => 'delete_project_sbom_occurrences'))

            expect(described_class).to receive(:perform_async)
              .with(hash_including('task' => 'delete_project_vulnerabilities'))
            expect(described_class).to receive(:perform_async)
              .with(hash_including('task' => 'delete_project_work_items'))

            described_class.new.perform({ task: :all })
          end
        end
      end

      describe 'PROJECT_TASKS contract' do
        it 'each task service builds a valid query with project_id only' do
          described_class::PROJECT_TASKS.each_value do |config|
            service_class = config[:service]
            expect(service_class).not_to be_nil
            expect { service_class.new(project_id: 1).send(:build_query) }.not_to raise_error
            expect(service_class.new(project_id: 1).send(:build_query)).to be_present
          end
        end
      end

      context 'when we pass valid task' do
        subject(:perform) { described_class.new.perform({ task: task }) }

        before do
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?).and_return(true)
        end

        context 'with delete_project_work_items task' do
          let(:task) { :delete_project_work_items }

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::ProjectWorkItemsService).to receive(:execute)
            perform
          end
        end

        context 'with delete_project_vulnerabilities task' do
          let(:task) { :delete_project_vulnerabilities }

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::VulnerabilityService).to receive(:execute)
            perform
          end
        end

        context 'with delete_project_vulnerability_reads task' do
          let(:task) { :delete_project_vulnerability_reads }

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::VulnerabilityReadsService).to receive(:execute)
            perform
          end
        end

        context 'with delete_project_sbom_occurrences task' do
          let(:task) { :delete_project_sbom_occurrences }

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::SbomOccurrenceRefsService).to receive(:execute)
            perform
          end
        end

        context 'with delete_all_blobs task' do
          let(:task) { :delete_all_blobs }

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::AllBlobsService).to receive(:execute)
            perform
          end
        end

        context 'with delete_tracked_context_sbom_occurrences task' do
          let(:task) { :delete_tracked_context_sbom_occurrences }

          it 'calls the corresponding service' do
            expect(::Search::Elastic::Delete::TrackedContextSbomOccurrenceRefsService).to receive(:execute)
            perform
          end

          context 'when the migration is unfinished' do
            let(:task) { :delete_tracked_context_sbom_occurrences }

            before do
              allow(::Elastic::DataMigrationService).to receive(:migration_has_finished?)
                .with(:create_sbom_occurrence_refs_index).and_return(false)
            end

            it 'does not call the service and returns false' do
              expect(::Search::Elastic::Delete::TrackedContextSbomOccurrenceRefsService).not_to receive(:execute)
              expect(perform).to be_falsey
            end
          end
        end
      end

      context 'when no task is provided' do
        it 'raises ArgumentError' do
          expect { described_class.new.perform({}) }.to raise_error(ArgumentError, 'Task must be provided')
        end
      end

      context 'when we pass invalid task' do
        let(:task) { :unknown_task }

        it 'raises ArgumentError' do
          expect { perform }.to raise_error(ArgumentError)
        end
      end
    end
  end
end
