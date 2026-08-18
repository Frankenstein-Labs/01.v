# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Milestones::DestroyService, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  subject(:service) { described_class.new(container, user, {}) }

  describe '#execute' do
    context 'on project milestones' do
      let_it_be(:container) { create(:project, maintainers: user) }

      let(:milestone) { create(:milestone, title: 'Milestone v1.0', project: container) }

      context 'with an existing merge request' do
        let!(:issue) { create(:issue, project: container, milestone: milestone) }
        let!(:merge_request) { create(:merge_request, source_project: container, milestone: milestone) }

        it 'manually queues MergeRequests::SyncCodeOwnerApprovalRulesWorker jobs' do
          expect(::MergeRequests::SyncCodeOwnerApprovalRulesWorker).to receive(:perform_async).with(merge_request.id)

          service.execute(milestone)
        end
      end
    end

    context 'on group milestones' do
      let_it_be(:container) { create(:group, maintainers: user) }

      let(:milestone) { create(:milestone, title: 'Milestone v1.0', group: container) }

      shared_examples 'deletes group-milestone' do |with_hooks:|
        it 'conditionally executes webhooks and does not create a new event' do
          if with_hooks
            expect(milestone.parent).to receive(:execute_hooks).with(a_hash_including(action: 'delete'),
              :milestone_hooks)
          end

          expect(Event).not_to receive(:new)

          service.execute(milestone)
          expect { milestone.reload }.to raise_error ActiveRecord::RecordNotFound
        end
      end

      context 'when group webhooks are available' do
        before do
          stub_licensed_features(group_webhooks: true)
        end

        context 'when group has active milestone hooks' do
          before do
            allow(container).to receive(:has_active_hooks?).with(:milestone_hooks).and_return(true)
          end

          it_behaves_like 'deletes group-milestone', with_hooks: true
        end

        context 'when group has no active milestone hooks' do
          it_behaves_like 'deletes group-milestone', with_hooks: false
        end
      end

      context 'when group webhooks are not available' do
        it_behaves_like 'deletes group-milestone', with_hooks: false
      end
    end
  end
end
