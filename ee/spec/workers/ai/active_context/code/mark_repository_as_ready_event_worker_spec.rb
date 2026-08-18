# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::MarkRepositoryAsReadyEventWorker, feature_category: :global_search do
  let(:event) { Ai::ActiveContext::Code::MarkRepositoryAsReadyEvent.new(data: {}) }
  let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }
  let_it_be(:collection) do
    create(:ai_active_context_collection, :code_collection, connection_id: connection.id)
  end

  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, active_context_connection: connection)
  end

  subject(:execute) { consume_event(subscriber: described_class, event: event) }

  describe '#handle_event', :clean_gitlab_redis_shared_state do
    context 'when indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive_messages(
          indexing?: true,
          indexing_embedding_fields: ['embeddings_v1']
        )
      end

      describe 'repositories with embedding indexing in progress' do
        let_it_be(:key1) { 'hash1' }
        let_it_be(:key2) { 'hash2' }
        let_it_be(:key3) { 'hash3' }

        let_it_be_with_reload(:repository1) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key1
          )
        end

        let_it_be_with_reload(:repository2) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key2
          )
        end

        let_it_be_with_reload(:repository3) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key3
          )
        end

        context 'when all repositories have embedding fields' do
          before do
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
              [{ 'id' => key1 }, { 'id' => key2 }, { 'id' => key3 }]
            )
          end

          it 'changes all repositories status to ready in a single bulk update' do
            expect { execute }.to change { repository1.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and change { repository2.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and change { repository3.reload.state }.from('embedding_indexing_in_progress').to('ready')
          end

          it 'uses an exists query and requests only the id field' do
            expect(Ai::ActiveContext::Collections::Code).to receive(:search).with(
              user: nil,
              query: an_instance_of(ActiveContext::Query),
              source_fields: ['id']
            ).and_return([{ 'id' => key1 }, { 'id' => key2 }, { 'id' => key3 }])

            execute
          end
        end

        context 'when two embedding fields are active (model migration in progress)' do
          before do
            allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing_embedding_fields)
              .and_return(%w[embeddings_v1 embeddings_v2])
          end

          context 'when the watermark document has both embedding fields' do
            before do
              allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
                [{ 'id' => key1 }, { 'id' => key2 }, { 'id' => key3 }]
              )
            end

            it 'marks all repositories as ready' do
              expect { execute }.to change {
                repository1.reload.state
              }.from('embedding_indexing_in_progress').to('ready')
                .and change { repository2.reload.state }.from('embedding_indexing_in_progress').to('ready')
                .and change { repository3.reload.state }.from('embedding_indexing_in_progress').to('ready')
            end
          end

          context 'when the watermark document has only one of the two embedding fields' do
            before do
              allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return([])
            end

            it 'does not mark any repository as ready' do
              expect { execute }.to not_change { repository1.reload.state }.from('embedding_indexing_in_progress')
                .and not_change { repository2.reload.state }.from('embedding_indexing_in_progress')
                .and not_change { repository3.reload.state }.from('embedding_indexing_in_progress')
            end
          end
        end

        context 'when only some repositories have embeddings (ES exists filter returns fewer docs)' do
          before do
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
              [{ 'id' => key1 }, { 'id' => key3 }]
            )
          end

          it 'only updates repositories whose documents were returned by the exists query' do
            expect { execute }.to change { repository1.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and change { repository3.reload.state }.from('embedding_indexing_in_progress').to('ready')
              .and not_change { repository2.reload.state }.from('embedding_indexing_in_progress')
          end
        end

        context 'when none of the repositories have embedding fields' do
          before do
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return([])
          end

          it 'does not update any repositories' do
            expect { execute }.to not_change { repository1.reload.state }.from('embedding_indexing_in_progress')
              .and not_change { repository2.reload.state }.from('embedding_indexing_in_progress')
              .and not_change { repository3.reload.state }.from('embedding_indexing_in_progress')
          end
        end
      end

      describe 'repositories have no initial_indexing_last_queued_item' do
        let_it_be(:key) { 'hash' }

        let_it_be_with_reload(:repository_with_item) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: key
          )
        end

        let_it_be_with_reload(:repository_without_item) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: nil
          )
        end

        before do
          allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return(
            [{ 'id' => key }]
          )
        end

        it 'only processes repositories with an item' do
          expect { execute }.to change {
            repository_with_item.reload.state
          }.from('embedding_indexing_in_progress').to('ready')
            .and not_change { repository_without_item.reload.state }.from('embedding_indexing_in_progress')
        end
      end

      describe 'no repositories with embedding indexing in progress' do
        let_it_be(:repository) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :pending,
            connection_id: connection.id
          )
        end

        it 'does nothing' do
          expect(::ActiveContext).not_to receive(:adapter)

          execute
        end
      end

      describe 'collection embedding fields' do
        let_it_be(:ref_id) { 'hash123' }

        let_it_be_with_reload(:active_context_repository) do
          create(:ai_active_context_code_repository,
            enabled_namespace: enabled_namespace,
            state: :embedding_indexing_in_progress,
            connection_id: connection.id,
            initial_indexing_last_queued_item: ref_id
          )
        end

        context 'when no embedding model is configured on the collection' do
          before do
            allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing_embedding_fields).and_return([])
          end

          it 'does not query Elasticsearch or change the repository status' do
            expect(Ai::ActiveContext::Collections::Code).not_to receive(:search)

            expect { execute }.not_to change {
              active_context_repository.reload.state
            }.from('embedding_indexing_in_progress')
          end
        end

        context 'when the collection has different `indexing_embedding_fields`' do
          before do
            allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing_embedding_fields)
              .and_return(['other_embedding_field'])
            allow(Ai::ActiveContext::Collections::Code).to receive(:search).and_return([])
          end

          it 'does not change the repository status' do
            expect { execute }.not_to change {
              active_context_repository.reload.state
            }.from('embedding_indexing_in_progress')
          end
        end
      end
    end

    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it 'does nothing' do
        expect(::ActiveContext).not_to receive(:adapter)

        execute
      end
    end
  end
end
