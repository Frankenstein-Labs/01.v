# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Git::BranchHooksService, feature_category: :duo_agent_platform do
  include RepoHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user) }

  let(:branch) { project.default_branch }
  let(:commit_id) { sample_commit.id }
  let(:commit) { project.commit(commit_id) }
  let(:ref) { "refs/heads/#{branch}" }
  let(:oldrev) { commit.parent_id }
  let(:newrev) { commit.id }
  let(:blankrev) { Gitlab::Git::SHA1_BLANK_SHA }

  let(:service) do
    described_class.new(project, user, change: { oldrev: oldrev, newrev: newrev, ref: ref })
  end

  describe '#enqueue_daily_foundational_flow' do
    before do
      create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: group)
      project.project_setting.update!(duo_vulnerability_context_analysis_enabled: true)
    end

    context 'when not the default branch' do
      let(:ref) { 'refs/heads/some-feature-branch' }

      it 'does not enqueue DailyFlowOnPushWorker' do
        expect(::Ai::DailyFlowOnPushWorker).not_to receive(:perform_async)

        service.send(:enqueue_daily_foundational_flow)
      end
    end

    context 'when creating a branch (not updating)' do
      let(:oldrev) { blankrev }

      it 'does not enqueue DailyFlowOnPushWorker' do
        expect(::Ai::DailyFlowOnPushWorker).not_to receive(:perform_async)

        service.send(:enqueue_daily_foundational_flow)
      end
    end

    context 'when removing a branch (not updating)' do
      let(:newrev) { blankrev }

      it 'does not enqueue DailyFlowOnPushWorker' do
        expect(::Ai::DailyFlowOnPushWorker).not_to receive(:perform_async)

        service.send(:enqueue_daily_foundational_flow)
      end
    end

    context 'when the pusher is a bot' do
      let_it_be(:user) { create(:user, :project_bot) }

      it 'does not enqueue DailyFlowOnPushWorker' do
        expect(::Ai::DailyFlowOnPushWorker).not_to receive(:perform_async)

        service.send(:enqueue_daily_foundational_flow)
      end
    end

    context 'when the feature flag is disabled' do
      before do
        stub_feature_flags(sdlc_context_agent_trigger: false)
      end

      it 'does not enqueue DailyFlowOnPushWorker' do
        expect(::Ai::DailyFlowOnPushWorker).not_to receive(:perform_async)

        service.send(:enqueue_daily_foundational_flow)
      end
    end

    context 'when duo_vulnerability_context_analysis_enabled is false' do
      before do
        project.project_setting.update!(duo_vulnerability_context_analysis_enabled: false)
      end

      it 'does not enqueue the worker' do
        expect(Ai::DailyFlowOnPushWorker).not_to receive(:perform_async)
        service.execute
      end
    end

    context 'when all conditions are met' do
      it 'enqueues DailyFlowOnPushWorker with project and user IDs' do
        expect(::Ai::DailyFlowOnPushWorker).to receive(:perform_async).with(project.id, user.id)

        service.send(:enqueue_daily_foundational_flow)
      end
    end
  end
end
