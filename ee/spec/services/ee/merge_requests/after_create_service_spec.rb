# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::AfterCreateService, feature_category: :code_review_workflow do
  # `freeze: false` is required in this spec: one or more `let_it_be` subjects
  # cannot be frozen by default (deep_freeze traversal failure, a non-AR
  # subject, or an in-memory mutation that survives reload/refind). Do not
  # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
  # (see gitlab-org/gitlab#602925).
  let_it_be(:merge_request, freeze: false) { create(:merge_request) }
  let_it_be(:project, freeze: false) { merge_request.target_project }

  let(:service_object) { described_class.new(project: project, current_user: merge_request.author) }

  describe '#execute' do
    subject(:execute) { service_object.execute(merge_request) }

    before do
      allow(::MergeRequests::NotifyApproversWorker).to receive(:perform_in)
    end

    it 'schedules approval notifications' do
      execute

      expect(::MergeRequests::NotifyApproversWorker).to have_received(:perform_in).with(10.seconds, merge_request.id)
    end

    it 'publishes created event' do
      expect { execute }
        .to publish_event(::MergeRequests::CreatedEvent).with(
          merge_request_id: merge_request.id
        )
    end

    it 'does not temporarily block MRs without approval rules' do
      expect(merge_request.approval_state).not_to receive(:temporarily_unapprove!)

      execute
    end

    it_behaves_like 'records an onboarding progress action', :merge_request_created do
      let(:namespace) { merge_request.target_project.namespace }
    end

    describe 'policy synchronization' do
      it_behaves_like 'synchronizes policies for a merge request' do
        before do
          allow(merge_request).to receive(:pipeline_creating?).and_return(false)
        end
      end
    end

    it_behaves_like 'audits security policy branch bypass'

    describe 'schedule_duo_code_review' do
      let(:merge_request) { create(:merge_request) }
      let(:current_user) { merge_request.author }
      let(:ai_review_allowed) { true }

      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?)
          .with(current_user)
          .and_return(ai_review_allowed)
      end

      context 'when Duo Code Review bot is not assigned as a reviewer' do
        it 'does not call ::Llm::ReviewMergeRequestService' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)

          execute
        end
      end

      context 'when Duo Code Review bot is assigned as a reviewer' do
        let(:duo_code_review_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

        before do
          merge_request.reviewers = [duo_code_review_bot]
        end

        context 'when AI review feature is not allowed' do
          let(:ai_review_allowed) { false }

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            execute
          end
        end

        context 'when AI review feature is allowed' do
          let(:ai_review_allowed) { true }

          it 'calls ::Llm::ReviewMergeRequestService' do
            expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
              expect(svc).to receive(:execute)
            end

            execute
          end
        end
      end
    end

    describe 'usage activity tracking' do
      let(:user) { merge_request.author }
      let(:event_name) { 'users_creating_merge_requests_with_security_policies' }

      context 'when project has no security policy configuration' do
        it "doesn't count event users_creating_merge_requests_with_security_policies" do
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).not_to receive(:track_event).with(event_name, any_args)

          execute
        end
      end

      context 'with project security_orchestration_policy_configuration' do
        before do
          configuration = create(:security_orchestration_policy_configuration, project: project)
          create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project)
        end

        it 'tracks users_creating_merge_requests_with_security_policies counter' do
          allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).with(event_name, values: user.id)

          execute
        end
      end

      context "with group security_orchestration_policy_configuration" do
        let_it_be(:configuration) { create(:security_orchestration_policy_configuration, :namespace) }

        before do
          create(:scan_result_policy_read, security_orchestration_policy_configuration: configuration, project: project)
          project.update!(namespace: configuration.namespace)
        end

        it 'tracks users_creating_merge_requests_with_security_policies counter' do
          allow(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event)
          expect(Gitlab::UsageDataCounters::HLLRedisCounter).to receive(:track_event).with(event_name, values: user.id)

          execute
        end
      end
    end

    context 'for audit events' do
      let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }
      let_it_be(:merge_request, freeze: false) { create(:merge_request, author: project_bot) }

      include_examples 'audit event logging' do
        let(:operation) { execute }
        let(:event_type) { 'merge_request_created_by_project_bot' }
        let(:fail_condition!) { expect(project_bot).to receive(:project_bot?).and_return(false) }
        let(:attributes) do
          {
            author_id: project_bot.id,
            entity_id: merge_request.target_project.id,
            entity_type: 'Project',
            details: {
              author_name: project_bot.name,
              event_name: 'merge_request_created_by_project_bot',
              target_id: merge_request.id,
              target_type: 'MergeRequest',
              target_details: {
                iid: merge_request.iid,
                id: merge_request.id,
                source_branch: merge_request.source_branch,
                target_branch: merge_request.target_branch
              }.to_s,
              author_class: project_bot.class.name,
              custom_message: "Created merge request #{merge_request.title}"
            }
          }
        end
      end
    end
  end
end
