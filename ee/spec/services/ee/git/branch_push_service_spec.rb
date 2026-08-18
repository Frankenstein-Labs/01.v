# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Git::BranchPushService, feature_category: :source_code_management do
  include RepoHelpers

  let_it_be(:user) { create(:user) }

  let(:blankrev)   { Gitlab::Git::SHA1_BLANK_SHA }
  let(:oldrev)     { sample_commit.parent_id }
  let(:newrev)     { sample_commit.id }
  let(:ref)        { 'refs/heads/master' }

  let(:params) do
    { change: { oldrev: oldrev, newrev: newrev, ref: ref } }
  end

  subject(:branch_push_service) { described_class.new(project, user, params) }

  context 'with pull project' do
    let_it_be_with_reload(:project) { create(:project, :repository, :mirror) }

    before do
      allow(project.repository).to receive(:commit).and_call_original
      allow(project.repository).to receive(:commit).with("master").and_return(nil)
    end

    context 'with ElasticSearch indexing', :elastic, :clean_gitlab_redis_shared_state,
      feature_category: :global_search do
      before do
        stub_ee_application_setting(elasticsearch_indexing?: true)
      end

      it 'runs Search::Elastic::CommitIndexerWorker' do
        expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(project.id)

        branch_push_service.execute
      end

      it "triggers indexer when push to default branch", :sidekiq_might_not_need_inline do
        expect_next_instance_of(Search::Elastic::Indexer) do |instance|
          expect(instance).to receive(:run)
        end

        branch_push_service.execute
      end

      context 'when push to non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it 'does not trigger indexer when push to non-default branch' do
          expect_any_instance_of(Search::Elastic::Indexer).not_to receive(:run)

          branch_push_service.execute
        end
      end

      context 'when limited indexing is on' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        context 'when the project is not enabled specifically' do
          it 'does not run Search::Elastic::CommitIndexerWorker' do
            expect(Search::Elastic::CommitIndexerWorker).not_to receive(:perform_async)

            branch_push_service.execute
          end
        end

        context 'when a project is enabled specifically' do
          before do
            create :elasticsearch_indexed_project, project: project
          end

          it 'runs Search::Elastic::CommitIndexerWorker' do
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(project.id)

            branch_push_service.execute
          end
        end

        context 'when a group is enabled' do
          let(:group) { create(:group) }
          let(:project) { create(:project, :repository, :mirror, group: group) }

          before do
            create :elasticsearch_indexed_namespace, namespace: group
          end

          it 'runs Search::Elastic::CommitIndexerWorker' do
            expect(Search::Elastic::CommitIndexerWorker).to receive(:perform_async).with(project.id)

            branch_push_service.execute
          end
        end
      end
    end

    context 'with Zoekt indexing', :zoekt_settings_enabled, feature_category: :global_search do
      let(:use_zoekt) { true }

      before do
        allow(project).to receive(:use_zoekt?).and_return(use_zoekt)
      end

      it 'triggers async_update_zoekt_index' do
        expect(project.repository).to receive(:async_update_zoekt_index)

        branch_push_service.execute
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it 'does not trigger async_update_zoekt_index' do
          expect(project.repository).not_to receive(:async_update_zoekt_index)

          branch_push_service.execute
        end
      end

      context 'when application_setting zoekt_indexing_enabled is disabled' do
        before do
          stub_ee_application_setting(zoekt_indexing_enabled: false)
        end

        it 'does not trigger async_update_zoekt_index' do
          expect(project.repository).not_to receive(:async_update_zoekt_index)

          branch_push_service.execute
        end
      end

      context 'when zoekt is not enabled for the project' do
        let(:use_zoekt) { false }

        it 'does not trigger async_update_zoekt_index' do
          expect(project.repository).not_to receive(:async_update_zoekt_index)

          branch_push_service.execute
        end
      end
    end

    context 'with external pull requests' do
      it 'runs UpdateExternalPullRequestsWorker' do
        expect(UpdateExternalPullRequestsWorker).to receive(:perform_async).with(project.id, user.id, ref)

        branch_push_service.execute
      end

      context 'when project is not mirror' do
        before do
          allow(project).to receive(:mirror?).and_return(false)
        end

        it 'does nothing' do
          expect(UpdateExternalPullRequestsWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end

      context 'when param skips pipeline creation' do
        before do
          params[:create_pipelines] = false
        end

        it 'does nothing' do
          expect(UpdateExternalPullRequestsWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end
    end

    describe 'Repository X-Ray dependency scanning', feature_category: :code_suggestions do
      before do
        project.update!(duo_features_enabled: true)
      end

      shared_examples 'does not enqueue the X-Ray worker' do
        it 'does not schedule a dependency scan' do
          expect(Ai::RepositoryXray::ScanDependenciesWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end

      context 'when pushing to the default branch' do
        it 'enqueues the X-Ray worker' do
          expect(Ai::RepositoryXray::ScanDependenciesWorker).to receive(:perform_async).with(project.id)

          branch_push_service.execute
        end

        context 'when the project does not have Duo features enabled' do
          before do
            project.update!(duo_features_enabled: false)
          end

          it_behaves_like 'does not enqueue the X-Ray worker'
        end
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it_behaves_like 'does not enqueue the X-Ray worker'
      end

      context 'when removing a branch' do
        let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

        it_behaves_like 'does not enqueue the X-Ray worker'
      end
    end

    describe 'trigger enqueue_knowledge_graph_code_indexing', feature_category: :knowledge_graph do
      shared_examples 'does not trigger enqueue_knowledge_graph_code_indexing' do
        it 'does not schedule a CodeIndexingWorker' do
          expect(::Analytics::KnowledgeGraph::CodeIndexingWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end

      shared_examples 'does trigger enqueue_knowledge_graph_code_indexing' do
        it 'does schedule a CodeIndexingWorker' do
          expect(::Analytics::KnowledgeGraph::CodeIndexingWorker)
            .to receive(:perform_async).with(project.id, ref, newrev)

          branch_push_service.execute
        end
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it_behaves_like 'does not trigger enqueue_knowledge_graph_code_indexing'
      end

      context 'when the knowledge_graph_infra feature flag is disabled' do
        before do
          stub_feature_flags(knowledge_graph_infra: false)
        end

        it_behaves_like 'does not trigger enqueue_knowledge_graph_code_indexing'
      end

      context 'when the namespace does not have knowledge graph enabled' do
        before do
          stub_feature_flags(knowledge_graph_infra: true)
        end

        it_behaves_like 'does not trigger enqueue_knowledge_graph_code_indexing'
      end

      context 'when pushing to the default branch with knowledge graph enabled' do
        before do
          stub_feature_flags(knowledge_graph_infra: true)
          create(:knowledge_graph_enabled_namespace, namespace: project.root_ancestor)
        end

        it_behaves_like 'does trigger enqueue_knowledge_graph_code_indexing'
      end
    end

    describe 'trigger enqueue_code_embedding_indexing', feature_category: :code_suggestions do
      shared_examples 'does not trigger enqueue_code_embedding_indexing' do
        it 'does not schedule a RepositoryIndexWorker' do
          expect(::Ai::ActiveContext::Code::RepositoryIndexWorker).not_to receive(:perform_async)

          branch_push_service.execute
        end
      end

      shared_examples 'does trigger enqueue_code_embedding_indexing' do
        it 'does schedule a RepositoryIndexWorker' do
          expect(::Ai::ActiveContext::Code::RepositoryIndexWorker).to receive(:perform_async).with(repository.id)

          branch_push_service.execute
        end
      end

      context 'when pushing to a non-default branch' do
        let(:ref) { 'refs/heads/other' }

        it_behaves_like 'does not trigger enqueue_code_embedding_indexing'
      end

      context 'when there is no Ai::ActiveContext::Code::Repository' do
        it_behaves_like 'does not trigger enqueue_code_embedding_indexing'
      end

      context 'with a code repository' do
        let_it_be_with_reload(:repository) do
          create(:ai_active_context_code_repository, state: :ready, project: project)
        end

        it_behaves_like 'does trigger enqueue_code_embedding_indexing'

        context 'when the Ai::ActiveContext::Code::Repository is not ready' do
          before do
            repository.update!(state: :pending)
          end

          it_behaves_like 'does not trigger enqueue_code_embedding_indexing'
        end
      end
    end

    describe 'Pipeline execution policy metadata sync' do
      let(:feature_licensed) { true }

      before do
        stub_licensed_features(security_orchestration_policies: feature_licensed)
      end

      context 'without any security_pipeline_execution_policy_config_link' do
        it 'does not run the worker' do
          expect(Security::SyncLinkedPipelineExecutionPolicyConfigsWorker).not_to receive(:perform_async)
        end
      end

      context 'with security_pipeline_execution_policy_config_link' do
        before do
          create(:security_pipeline_execution_policy_config_link, project: project)
        end

        it 'runs a worker' do
          expect(Security::SyncLinkedPipelineExecutionPolicyConfigsWorker)
            .to receive(:perform_async)
                  .with(project.id, user.id, oldrev, newrev, ref)
                  .ordered

          branch_push_service.execute
        end

        context 'when feature is not licensed' do
          let(:feature_licensed) { false }

          it 'does not run the worker' do
            expect(Security::SyncLinkedPipelineExecutionPolicyConfigsWorker).not_to receive(:perform_async)
          end
        end
      end
    end
  end
end
