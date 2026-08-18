# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::CallbackService, feature_category: :global_search do
  let_it_be(:node) { create(:zoekt_node, schema_version: 2525) }
  let(:service) { described_class.new(node, params) }

  describe '.execute' do
    let(:params) { {} }

    it 'passes arguments to new and calls execute' do
      expect(described_class).to receive(:new).with(node, params).and_return(service)
      expect(service).to receive(:execute)

      described_class.execute(node, params)
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    let(:service_type) { 'zoekt' }
    let(:additional_payload) { { 'repo_stats' => { index_file_count: 1, size_in_bytes: 582790 } } }
    let(:params) do
      {
        'name' => task_type,
        'success' => success,
        'payload' => { 'task_id' => task_id, 'service_type' => service_type },
        'additional_payload' => additional_payload
      }
    end

    let(:success) { true }

    context 'when task is not found' do
      let(:task_id) { non_existing_record_id }
      let(:task_type) { 'index' }

      it 'does not perform anything' do
        expect(execute).to be_nil
      end
    end

    context 'for successful operation' do
      let_it_be_with_reload(:index_zoekt_task) { create(:zoekt_task, node: node) }

      context 'when task is already done' do
        let(:task_type) { 'index' }
        let(:task_id) { index_zoekt_task.id }

        before do
          index_zoekt_task.done!
        end

        it 'does not update the zoekt_repository indexed_at' do
          expect { execute }.not_to change { index_zoekt_task.reload.zoekt_repository.indexed_at }
        end
      end

      context 'when the task type is index' do
        before do
          index_zoekt_task.zoekt_repository.update!(retries_left: 2)
        end

        let(:task_type) { 'index' }
        let(:task_id) { index_zoekt_task.id }

        it 'updates the task state, zoekt_repository data' do
          freeze_time do
            expect { execute }.to change { index_zoekt_task.reload.state }.to('done')
              .and change { index_zoekt_task.zoekt_repository.indexed_at }.to(Time.current)
                .and change { index_zoekt_task.zoekt_repository.state }.to('ready')
                  .and change { index_zoekt_task.zoekt_repository.index_file_count }.to(1)
                    .and change { index_zoekt_task.zoekt_repository.size_bytes }.to(582790)
                      .and change { index_zoekt_task.zoekt_repository.retries_left }.from(2).to(10)
                        .and change { index_zoekt_task.zoekt_repository.zoekt_index.last_indexed_at }.to(Time.current)
                          .and change { index_zoekt_task.zoekt_repository.schema_version }.from(0).to(2525)
          end
        end

        context 'when updating index timestamps', :freeze_time do
          let(:task_type) { 'index' }
          let(:task_id) { index_zoekt_task.id }
          let(:repo) { index_zoekt_task.zoekt_repository }
          let(:index) { repo.zoekt_index }

          it 'updates timestamp when difference is more than the minimum interval' do
            old_time = (described_class::LAST_INDEXED_DEBOUNCE_PERIOD + 1.second).ago
            index.update!(last_indexed_at: old_time)

            expect { execute }.to change { index.reload.last_indexed_at }.from(old_time).to(Time.current)
          end

          it 'does not update timestamp when difference is less than the minimum interval' do
            recent_time = (described_class::LAST_INDEXED_DEBOUNCE_PERIOD - 1.second).ago
            index.update!(last_indexed_at: recent_time)

            expect { execute }.not_to change { index.reload.last_indexed_at }
          end

          it 'updates timestamp on first indexing' do
            old_time = Time.zone.at(0)
            index.update!(last_indexed_at: old_time)

            expect { execute }.to change { index.reload.last_indexed_at }.from(old_time).to(Time.current)
          end
        end
      end

      context 'when the task type is delete' do
        let(:task_type) { 'delete' }
        let_it_be_with_reload(:delete_zoekt_task) { create(:zoekt_task, task_type: :delete_repo, node: node) }
        let(:task_id) { delete_zoekt_task.id }

        it 'deletes the zoekt_repository' do
          expect { execute }.to change { delete_zoekt_task.reload.state }.to('done')
          expect(delete_zoekt_task.zoekt_repository).to be_nil
        end

        context 'when repository is already deleted' do
          before do
            delete_zoekt_task.zoekt_repository.destroy!
          end

          it 'moves the task to done' do
            expect { execute }.to change { delete_zoekt_task.reload.state }.to('done')
          end
        end
      end

      context 'when incrementing apdex SLI metric' do
        let(:task_type) { 'index' }
        let(:task_id) { index_zoekt_task.id }

        it 'increments apdex metric with correct labels and duration' do
          freeze_time do
            expect(Gitlab::Metrics::ZoektTasksSlis).to receive(:increment_apdex).with(
              zoekt_node_id: index_zoekt_task.zoekt_node_id,
              task_type: index_zoekt_task.task_type,
              duration: instance_of(Float)
            )

            execute
          end
        end

        context 'when task completes within apdex threshold' do
          it 'records success for apdex' do
            index_zoekt_task.update!(perform_at: 2.minutes.ago)

            expect(Gitlab::Metrics::Sli::Apdex[:search_zoekt_tasks]).to receive(:increment).with(
              labels: { zoekt_node: index_zoekt_task.zoekt_node_id.to_s, task_type: index_zoekt_task.task_type.to_s },
              success: true
            )

            execute
          end
        end

        context 'when task exceeds apdex threshold' do
          it 'records failure for apdex' do
            index_zoekt_task.update!(perform_at: (Gitlab::Metrics::ZoektTasksSlis::APDEX_THRESHOLD_S + 60).seconds.ago)

            expect(Gitlab::Metrics::Sli::Apdex[:search_zoekt_tasks]).to receive(:increment).with(
              labels: { zoekt_node: index_zoekt_task.zoekt_node_id.to_s, task_type: index_zoekt_task.task_type.to_s },
              success: false
            )

            execute
          end
        end
      end
    end

    context 'for non-successful operation' do
      let(:task_type) { 'delete' }
      let(:task_id) { zoekt_task.id }
      let(:success) { false }
      let(:jitter) { base_delay * 0.5 }

      context 'for first failure', :freeze_time do
        let_it_be(:zoekt_task) { create(:zoekt_task, node: node) }
        let(:base_delay) { Search::Zoekt::Task::RETRY_DELAY }

        it 'updates retries_left and perform_at without updating the task state and repository schema_version' do
          zoekt_repository_initial_schema_version = zoekt_task.zoekt_repository.schema_version
          expect { execute }.to change { zoekt_task.reload.retries_left }.by(-1).and not_change { zoekt_task.state }
          expect(zoekt_task.perform_at).to be_within(jitter).of(base_delay.from_now)
          expect(zoekt_task.zoekt_repository.reload.schema_version).to eq zoekt_repository_initial_schema_version
        end
      end

      context 'for second failure', :freeze_time do
        let_it_be(:zoekt_task) { create(:zoekt_task, node: node, retries_left: 2) }
        let(:base_delay) { Search::Zoekt::Task::RETRY_DELAY * 2 }

        it 'updates retries_left and perform_at without updating the task state' do
          expect { execute }.to change { zoekt_task.reload.retries_left }.by(-1).and not_change { zoekt_task.state }
          expect(zoekt_task.perform_at).to be_within(jitter).of(base_delay.from_now)
        end
      end

      context 'when no retries left' do
        let_it_be(:zoekt_task) { create(:zoekt_task, node: node, retries_left: 1) }

        it 'updates the task state to failed' do
          expect { execute }.to change { zoekt_task.reload.retries_left }.from(1).to(0)
            .and change { zoekt_task.state }.to('failed')
        end

        it 'publishes a TaskFailed event with zoekt_repository_id' do
          expected_data = { zoekt_repository_id: zoekt_task.zoekt_repository_id, task_id: zoekt_task.id }

          expect { service.execute }.to publish_event(Search::Zoekt::TaskFailedEvent).with(expected_data)
        end
      end

      context 'when incrementing errorRate SLI metric' do
        let_it_be(:zoekt_task) { create(:zoekt_task, node: node, retries_left: 1) }

        it 'increments error counter when task reaches failed state' do
          expect(Gitlab::Metrics::ZoektTasksSlis).to receive(:increment_error_count).with(
            zoekt_node_id: zoekt_task.zoekt_node_id,
            task_type: zoekt_task.task_type
          )

          execute
        end

        it 'increments ErrorRate SLI with correct labels' do
          expect(Gitlab::Metrics::Sli::ErrorRate[:search_zoekt_tasks]).to receive(:increment).with(
            labels: { zoekt_node: zoekt_task.zoekt_node_id.to_s, task_type: zoekt_task.task_type.to_s },
            error: true
          )

          execute
        end

        context 'when task still has retries left' do
          let_it_be(:zoekt_task) { create(:zoekt_task, node: node, retries_left: 3) }

          it 'does not increment error counter on retry' do
            expect(Gitlab::Metrics::ZoektTasksSlis).not_to receive(:increment_error_count)

            execute
          end
        end

        context 'when task is already failed' do
          let_it_be(:zoekt_task) { create(:zoekt_task, :failed, node: node) }

          it 'does not increment error counter for already failed task' do
            expect(Gitlab::Metrics::ZoektTasksSlis).not_to receive(:increment_error_count)

            execute
          end
        end
      end
    end
  end
end
