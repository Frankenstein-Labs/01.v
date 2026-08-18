# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MergeRequests::RequestReviewService, feature_category: :code_review_workflow do
  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:user, freeze: false) { ::Users::Internal.in_organization(current_user.organization_id).duo_code_review_bot }
  let_it_be(:merge_request, freeze: false) { create(:merge_request, reviewers: [user]) }

  let(:service) { described_class.new(project: merge_request.project, current_user: current_user) }

  before_all do
    merge_request.project.add_developer(current_user)
  end

  context 'when requesting review from duo code review bot' do
    before do
      allow(merge_request.merge_request_diff).to receive_messages(
        persisted?: persisted,
        empty?: empty
      )

      allow(merge_request).to receive(:ai_review_merge_request_allowed?)
        .with(current_user)
        .and_return(ai_review_allowed)
    end

    context 'when AI review feature is not allowed' do
      let(:ai_review_allowed) { false }
      let(:persisted) { true }
      let(:empty) { false }

      it 'does not call any review service' do
        expect(Llm::ReviewMergeRequestService).not_to receive(:new)
        expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

        response = service.execute(merge_request, user)
        expect(response[:status]).to eq :error
        expect(response[:message]).to include "You don't have access to GitLab Duo Code Review."
      end
    end

    context 'when AI review feature is allowed' do
      let(:ai_review_allowed) { true }
      let(:empty) { false }

      context 'when merge_request_diff is not persisted yet' do
        let(:persisted) { false }

        it 'does not call any review service' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)
          expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

          service.execute(merge_request, user)
        end
      end

      context 'when merge_request_diff is persisted' do
        let(:persisted) { true }

        context 'with Duo Enterprise using classic flow' do
          let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

          before do
            stub_feature_flags(duo_code_review_dap_internal_users: false)
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
            merge_request.project.project_setting.update!(duo_features_enabled: true)
          end

          it 'calls ::Llm::ReviewMergeRequestService' do
            expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
              expect(svc).to receive(:execute)
            end

            service.execute(merge_request, user)
          end

          it 'does not call DAP service' do
            allow_next_instance_of(Llm::ReviewMergeRequestService) do |svc|
              allow(svc).to receive(:execute)
            end

            expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

            service.execute(merge_request, user)
          end

          context 'when merge_request_diff is empty' do
            let(:empty) { true }

            it 'does not call any review service' do
              expect(Llm::ReviewMergeRequestService).not_to receive(:new)
              expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

              service.execute(merge_request, user)
            end
          end
        end

        context 'with DAP flow (Duo Core/Pro or Duo Enterprise with internal flag)' do
          let!(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }

          before do
            merge_request.project.project_setting.update!(duo_features_enabled: true,
              duo_foundational_flows_enabled: true)
            create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_core_add_on)

            allow(::Gitlab::Duo::CodeReview).to receive(:dap?).and_return(true)
          end

          it 'calls Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService' do
            expect_next_instance_of(
              Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService,
              user: current_user,
              merge_request: merge_request
            ) do |svc|
              expect(svc).to receive(:execute)
            end

            service.execute(merge_request, user)
          end

          it 'does not call legacy Llm::ReviewMergeRequestService' do
            allow_next_instance_of(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService) do |svc|
              allow(svc).to receive(:execute)
            end

            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            service.execute(merge_request, user)
          end

          context 'when merge_request_diff is empty' do
            let(:empty) { true }

            it 'does not trigger any review service' do
              expect(Llm::ReviewMergeRequestService).not_to receive(:new)
              expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

              service.execute(merge_request, user)
            end
          end
        end
      end
    end
  end

  context 'when a service account linked to a flow trigger' do
    let_it_be(:service_account, freeze: false) { create(:service_account, username: 'flow-trigger-1') }

    let_it_be(:flow_trigger, freeze: false) do
      create(:ai_flow_trigger, project: merge_request.project, event_types: [2], user: service_account)
    end

    let(:run_service) { instance_double(::Ai::FlowTriggers::RunService) }

    before do
      merge_request.project.add_developer(service_account)

      allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(merge_request.project,
        :duo_workflow).and_return(true)
      stub_ee_application_setting(duo_features_enabled: true)
      allow(current_user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)
    end

    context 'when requesting review from this account' do
      it 'triggers the AI flow' do
        merge_request.reviewers << service_account

        expect(run_service).to receive(:execute).with(
          { input: merge_request.iid.to_s, event: :assign_reviewer, triggered_by_username: current_user.username }
        )
        expect(::Ai::FlowTriggers::RunService).to receive(:new)
          .with(
            project: merge_request.project, current_user: current_user,
            resource: merge_request, flow_trigger: flow_trigger
          ).and_return(run_service)

        service.execute(merge_request, service_account)
      end
    end
  end
end
