# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Code::AdHocIndexingWorker, feature_category: :global_search do
  let_it_be(:root_namespace) { create(:group) }
  let_it_be(:project) { create(:project, namespace: create(:group, parent: root_namespace)) }
  let_it_be(:connection) do
    create(:ai_active_context_connection, :elasticsearch)
  end

  let_it_be(:enabled_namespace) do
    create(
      :ai_active_context_code_enabled_namespace,
      namespace: project.root_namespace,
      connection_id: connection.id,
      state: :ready
    )
  end

  subject(:perform) { described_class.new.perform(project.id) }

  shared_examples 'does not start indexing' do
    it 'returns false and does not process' do
      expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }
      expect(perform).to be false
    end
  end

  describe '#perform' do
    context 'when indexing is disabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(false)
      end

      it_behaves_like 'does not start indexing'
    end

    context 'when indexing is enabled' do
      before do
        allow(::Ai::ActiveContext::Collections::Code).to receive(:indexing?).and_return(true)
      end

      context 'with invalid project_id' do
        subject(:perform) { described_class.new.perform(non_existing_record_id) }

        it_behaves_like 'does not start indexing'
      end

      context 'when project exists' do
        before do
          project.reload.project_setting.update!(duo_features_enabled: true)
        end

        it 'ensures a fresh check on eligibility' do
          expect(Rails.cache).to receive(:fetch).with(
            "active_context_code_eligible_project_#{project.id}",
            expires_in: described_class::CODE_ELIGIBILITY_CACHE_EXPIRY,
            force: true
          ).and_call_original

          perform
        end

        context 'when project is not eligible for indexing' do
          context 'when duo_features_enabled is false' do
            before do
              project.reload.project_setting.update!(duo_features_enabled: false)
            end

            it_behaves_like 'does not start indexing'
          end

          context "when not in GA and project's root namespace has experiment features disabled" do
            before do
              stub_feature_flags(semantic_code_search_saas_ga: false)
              root_namespace.reload.namespace_settings.update!(experiment_features_enabled: false)
            end

            it_behaves_like 'does not start indexing'
          end

          context 'when no enabled namespace exists for the project' do
            before do
              enabled_namespace.destroy!
            end

            it_behaves_like 'does not start indexing'
          end
        end

        context 'when project is eligible for indexing' do
          context 'when repository record already exists' do
            let!(:existing_repository) do
              create(:ai_active_context_code_repository,
                project: project, connection_id: connection.id, enabled_namespace: enabled_namespace)
            end

            it_behaves_like 'does not start indexing'

            context 'when repository record already exists in deleted state' do
              before do
                existing_repository.update!(state: :deleted, delete_reason: 'test_reason')
              end

              it 'updates the repository state to pending, clears delete_reason, and enqueues RepositoryIndexWorker' do
                expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async)
                  .with(existing_repository.id)

                expect { perform }.not_to change { Ai::ActiveContext::Code::Repository.count }

                existing_repository.reload
                expect(existing_repository.state).to eq('pending')
                expect(existing_repository.delete_reason).to be_nil
              end
            end
          end

          context 'when repository record does not exist' do
            it 'creates repository record and enqueues RepositoryIndexWorker' do
              expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async)

              expect { perform }.to change { Ai::ActiveContext::Code::Repository.count }.by(1)

              repository = Ai::ActiveContext::Code::Repository.last
              expect(repository.project_id).to eq(project.id)
              expect(repository.enabled_namespace_id).to eq(enabled_namespace.id)
              expect(repository.connection_id).to eq(connection.id)
              expect(repository.state).to eq('pending')
            end

            it 'calls RepositoryIndexWorker with correct repository id' do
              expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async) do |repository_id|
                repository = Ai::ActiveContext::Code::Repository.find(repository_id)
                expect(repository.project_id).to eq(project.id)
              end

              perform
            end
          end

          context "when on saas, not GA, and project's root namespace has experiment features enabled", :saas do
            before do
              stub_feature_flags(semantic_code_search_saas_ga: false)
              root_namespace.reload.namespace_settings.update!(experiment_features_enabled: true)
            end

            it 'creates repository record and enqueues RepositoryIndexWorker' do
              expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async)

              expect { perform }.to change { Ai::ActiveContext::Code::Repository.count }.by(1)

              repository = Ai::ActiveContext::Code::Repository.last
              expect(repository.project_id).to eq(project.id)
              expect(repository.enabled_namespace_id).to eq(enabled_namespace.id)
              expect(repository.connection_id).to eq(connection.id)
              expect(repository.state).to eq('pending')
            end
          end

          context "when not on saas, not GA, and project's root namespace has experiment features disabled" do
            before do
              allow(::License).to receive(:ai_features_available?).and_return(true)
              stub_feature_flags(semantic_code_search_saas_ga: false)
              root_namespace.reload.namespace_settings.update!(experiment_features_enabled: false)
            end

            it 'creates repository record and enqueues RepositoryIndexWorker' do
              expect(Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async)

              expect { perform }.to change { Ai::ActiveContext::Code::Repository.count }.by(1)

              repository = Ai::ActiveContext::Code::Repository.last
              expect(repository.project_id).to eq(project.id)
              expect(repository.enabled_namespace_id).to eq(enabled_namespace.id)
              expect(repository.connection_id).to eq(connection.id)
              expect(repository.state).to eq('pending')
            end
          end
        end
      end

      it_behaves_like 'worker with data consistency', described_class, data_consistency: :sticky

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { [project.id] }
      end
    end
  end
end
