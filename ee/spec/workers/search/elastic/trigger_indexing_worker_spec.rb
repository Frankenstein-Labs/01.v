# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::TriggerIndexingWorker, :elastic, feature_category: :global_search do
  let(:task_executor_service) { instance_double(Search::RakeTaskExecutorService) }
  let(:job_args) { nil }
  let(:worker) { described_class.new }

  subject(:perform) { worker.perform(*job_args) }

  before do
    stub_ee_application_setting(elasticsearch_indexing: true, elasticsearch_pause_indexing: true)

    allow(worker).to receive(:task_executor_service).and_return(task_executor_service)
  end

  it_behaves_like 'worker with data consistency', described_class, data_consistency: :delayed

  describe '#perform' do
    context 'when on saas', :saas do
      it 'returns false and does nothing' do
        expect(task_executor_service).not_to receive(:execute)
        expect(perform).to be false
      end
    end

    context 'when unknown task is provided' do
      let(:job_args) { 'foo' }

      it 'raises ArgumentError' do
        expect(task_executor_service).not_to receive(:execute)
        expect { perform }.to raise_error(ArgumentError, 'Unknown task: foo')
      end
    end

    context 'when no task is provided' do
      let(:job_args) { nil }
      let(:tasks_to_schedule) { described_class::TASKS }

      before do
        tasks_to_schedule.each do |task|
          allow(described_class).to receive(:perform_async).with(task, {})
        end
      end

      it 'schedules other tasks' do
        expect(task_executor_service).to receive(:execute).with(:recreate_index)
        expect(task_executor_service).to receive(:execute).with(:clear_index_status)
        expect(task_executor_service).to receive(:execute).with(:clear_reindex_status)
        expect(task_executor_service).to receive(:execute).with(:clear_tracking_queues)
        expect(task_executor_service).to receive(:execute).with(:resume_advanced_search_indexing)

        tasks_to_schedule.each do |task|
          expect(described_class).to receive(:perform_async).with(task, {})
        end

        perform
      end
    end

    context 'for task: initiate' do
      context 'when no options provided' do
        let(:job_args) { 'initiate' }
        let(:tasks_to_schedule) { described_class::TASKS }

        it_behaves_like 'an idempotent worker' do
          before do
            tasks_to_schedule.each do |task|
              allow(described_class).to receive(:perform_async).with(task, {})
            end
          end

          it 'recreates the index, clears index status, clears reindex status, and schedules other tasks' do
            expect(task_executor_service).to receive(:execute).with(:recreate_index)
            expect(task_executor_service).to receive(:execute).with(:clear_index_status)
            expect(task_executor_service).to receive(:execute).with(:clear_reindex_status)
            expect(task_executor_service).to receive(:execute).with(:clear_tracking_queues)
            expect(task_executor_service).to receive(:execute).with(:resume_advanced_search_indexing)

            tasks_to_schedule.each do |task|
              expect(described_class).to receive(:perform_async).with(task, {})
            end

            perform
          end

          context 'when only the advanced search pause flag is set (not the cluster pause)' do
            before do
              stub_ee_application_setting(elasticsearch_pause_indexing: false,
                elasticsearch_advanced_search_pause_indexing: true)
            end

            it 'recreates the index, clears index status, clears reindex status, and schedules other tasks' do
              expect(task_executor_service).to receive(:execute).with(:recreate_index)
              expect(task_executor_service).to receive(:execute).with(:clear_index_status)
              expect(task_executor_service).to receive(:execute).with(:clear_reindex_status)
              expect(task_executor_service).to receive(:execute).with(:clear_tracking_queues)
              expect(task_executor_service).to receive(:execute).with(:resume_advanced_search_indexing)

              tasks_to_schedule.each do |task|
                expect(described_class).to receive(:perform_async).with(task, {})
              end

              perform
            end
          end

          context 'when advanced search indexing has not been paused yet' do
            before do
              stub_ee_application_setting(elasticsearch_pause_indexing: false,
                elasticsearch_advanced_search_pause_indexing: false)
            end

            it 'pauses indexing and reschedules itself' do
              expect(task_executor_service).to receive(:execute).with(:pause_advanced_search_indexing)
              expect(described_class).to receive(:perform_in)
                .with(described_class::DEFAULT_DELAY, described_class::INITIAL_TASK, {})

              expect(perform).to be false
            end

            context 'when in development environment' do
              before do
                stub_rails_env('development')
              end

              it 'pauses indexing and runs itself without delay' do
                expect(task_executor_service).to receive(:execute).with(:pause_advanced_search_indexing)
                expect(described_class).to receive(:perform_async).with(described_class::INITIAL_TASK, {})

                expect(perform).to be false
              end
            end
          end

          context 'when indexing is disabled' do
            before do
              stub_ee_application_setting(elasticsearch_indexing: false)
            end

            it 'enables indexing and reschedules itself' do
              expect(ApplicationSettings::UpdateService).to receive(:new).with(
                Gitlab::CurrentSettings.current_application_settings,
                nil,
                { elasticsearch_indexing: true }).and_call_original
              expect(task_executor_service).not_to receive(:execute)
              expect(described_class).to receive(:perform_in)
                .with(described_class::DEFAULT_DELAY, described_class::INITIAL_TASK, {})

              expect(perform).to be false
            end

            context 'when in development environment' do
              before do
                stub_rails_env('development')
              end

              it 'enables indexing and runs itself without delay' do
                expect(ApplicationSettings::UpdateService).to receive(:new).with(
                  Gitlab::CurrentSettings.current_application_settings,
                  nil,
                  { elasticsearch_indexing: true }).and_call_original
                expect(task_executor_service).not_to receive(:execute)
                expect(described_class).to receive(:perform_async).with(described_class::INITIAL_TASK, {})

                expect(perform).to be false
              end
            end
          end
        end
      end

      context 'when skip option is provided' do
        let(:job_args) { ['initiate', options] }
        let(:options) { { 'skip' => 'projects' } }
        let(:tasks_to_schedule) { described_class::TASKS - [:initiate, :projects] }

        it 'recreates the index, clears index status, clears reindex status, and schedules other tasks' do
          expect(task_executor_service).to receive(:execute).with(:recreate_index)
          expect(task_executor_service).to receive(:execute).with(:clear_index_status)
          expect(task_executor_service).to receive(:execute).with(:clear_reindex_status)
          expect(task_executor_service).to receive(:execute).with(:clear_tracking_queues)
          expect(task_executor_service).to receive(:execute).with(:resume_advanced_search_indexing)

          tasks_to_schedule.each do |task|
            expect(described_class).to receive(:perform_async).with(task, options)
          end

          perform
        end
      end
    end

    context 'for task: snippets' do
      let(:job_args) { 'snippets' }

      it_behaves_like 'an idempotent worker' do
        it 'indexes snippets' do
          expect(task_executor_service).to receive(:execute).with(:index_snippets)

          perform
        end
      end
    end

    context 'for task: namespaces' do
      let(:job_args) { 'namespaces' }

      it_behaves_like 'an idempotent worker' do
        it 'indexes namespaces' do
          expect(task_executor_service).to receive(:execute).with(:index_namespaces)

          perform
        end
      end
    end

    context 'for task: projects' do
      let(:job_args) { 'projects' }

      it_behaves_like 'an idempotent worker' do
        it 'indexes projects' do
          expect(task_executor_service).to receive(:execute).with(:index_projects)

          perform
        end
      end
    end

    context 'for task: users' do
      let_it_be(:users) { create_list(:user, 3) }

      let(:job_args) { 'users' }

      it_behaves_like 'an idempotent worker' do
        it 'indexes users' do
          expect(task_executor_service).to receive(:execute).with(:index_users)

          perform
        end
      end
    end

    context 'for task: vulnerabilities' do
      let(:job_args) { 'vulnerabilities' }

      it_behaves_like 'an idempotent worker' do
        it 'indexes vulnerabilities' do
          expect(task_executor_service).to receive(:execute).with(:index_vulnerabilities)

          perform
        end
      end
    end

    context 'for task: sbom_occurrence_refs' do
      let(:job_args) { 'sbom_occurrence_refs' }

      it_behaves_like 'an idempotent worker' do
        it 'indexes SBOM occurrence refs' do
          expect(task_executor_service).to receive(:execute).with(:index_sbom_occurrence_refs)

          perform
        end
      end
    end
  end
end
