# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::AutoAssignReviewersWorker, feature_category: :code_review_workflow do
  let_it_be_with_reload(:project) do
    create(:project).tap do |p|
      p.project_setting.update!(reviewer_assignment_strategy: 'code_owners')
    end
  end

  let_it_be(:author) { create(:user) }

  let(:merge_request) { create(:merge_request, source_project: project, author: author) }

  before_all do
    project.add_developer(author)
  end

  before do
    stub_licensed_features(merge_request_approvers: true, multiple_merge_request_reviewers: true, code_owners: true)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [merge_request.id] }
  end

  describe '#perform' do
    context 'when merge request does not exist' do
      it 'does nothing' do
        expect(MergeRequests::ReviewerAssignment::AssignService).not_to receive(:new)

        described_class.new.perform(non_existing_record_id)
      end
    end

    context 'when reviewer auto assignment is disabled' do
      before do
        merge_request.project.project_setting.update!(reviewer_assignment_strategy: 'disabled')
      end

      it 'does nothing' do
        expect(MergeRequests::ReviewerAssignment::AssignService).not_to receive(:new)

        described_class.new.perform(merge_request.id)
      end
    end

    context 'when the merge request is a draft' do
      before do
        merge_request.update!(title: "Draft: #{merge_request.title}")
      end

      it 'does not assign reviewers' do
        expect(MergeRequests::ReviewerAssignment::AssignService).not_to receive(:new)

        described_class.new.perform(merge_request.id)
      end
    end

    context 'when a non-automated reviewer is already assigned' do
      before do
        merge_request.reviewers = [create(:user)]
      end

      it 'does not assign reviewers' do
        expect(MergeRequests::ReviewerAssignment::AssignService).not_to receive(:new)

        described_class.new.perform(merge_request.id)
      end
    end

    context 'when only the Duo Code Review bot is assigned as a reviewer' do
      before do
        merge_request.reviewers = [create(:user, :duo_code_review_bot)]
      end

      it 'still delegates to AssignService' do
        expect_next_instance_of(
          MergeRequests::ReviewerAssignment::AssignService,
          merge_request: merge_request,
          current_user: author
        ) do |service|
          expect(service).to receive(:execute)
        end

        described_class.new.perform(merge_request.id)
      end
    end

    context 'when reviewer_assignment_strategy is code_owners' do
      it 'delegates to AssignService with the merge request author as current_user' do
        expect_next_instance_of(
          MergeRequests::ReviewerAssignment::AssignService,
          merge_request: merge_request,
          current_user: author
        ) do |service|
          expect(service).to receive(:execute)
        end

        described_class.new.perform(merge_request.id)
      end
    end

    context 'when reviewer_assignment_strategy is dap_powered' do
      let_it_be(:catalog_item) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'recommend_reviewers/v1')
      end

      before do
        project.project_setting.update!(
          reviewer_assignment_strategy: 'dap_powered',
          duo_foundational_flows_enabled: true
        )
        create(:ai_catalog_enabled_foundational_flow, :for_project,
          project: project, catalog_item: catalog_item)
        allow(::Gitlab::Llm::StageCheck).to receive(:available?)
          .with(project, :duo_workflow).and_return(true)
      end

      context 'when DAP is available' do
        let(:execute_result) { ServiceResponse.success(payload: { workflow: instance_double(::Ai::DuoWorkflows::Workflow, id: 42) }) }

        it 'delegates to RecommendReviewers::ExecuteService with the merge request author' do
          expect_next_instance_of(
            ::Ai::DuoWorkflows::RecommendReviewers::ExecuteService,
            merge_request: merge_request,
            current_user: author
          ) do |service|
            expect(service).to receive(:execute).and_return(execute_result)
          end

          expect(MergeRequests::ReviewerAssignment::AssignService).not_to receive(:new)

          described_class.new.perform(merge_request.id)
        end

        it 'tracks the auto_assign_reviewers event' do
          allow_next_instance_of(::Ai::DuoWorkflows::RecommendReviewers::ExecuteService) do |service|
            allow(service).to receive(:execute).and_return(execute_result)
          end

          expect { described_class.new.perform(merge_request.id) }
            .to trigger_internal_events('auto_assign_reviewers')
            .with(
              project: project,
              namespace: project.namespace,
              user: author,
              additional_properties: { label: 'dap_powered' }
            )
        end
      end

      context 'when DAP is not available' do
        before do
          stub_feature_flags(dap_powered_recommend_reviewers: false)
        end

        it 'does not invoke any assignment service' do
          expect(::Ai::DuoWorkflows::RecommendReviewers::ExecuteService).not_to receive(:new)
          expect(MergeRequests::ReviewerAssignment::AssignService).not_to receive(:new)

          described_class.new.perform(merge_request.id)
        end
      end

      context 'when ExecuteService returns an error' do
        let(:error_result) { ServiceResponse.error(message: 'token generation failed') }

        it 'logs a warning and does not track the event' do
          allow_next_instance_of(::Ai::DuoWorkflows::RecommendReviewers::ExecuteService) do |service|
            allow(service).to receive(:execute).and_return(error_result)
          end

          expect_next_instance_of(described_class) do |worker|
            expect(worker).to receive(:logger).and_call_original
            expect(Sidekiq.logger).to receive(:warn).with(
              hash_including(
                'message' => /Failed to start Duo Agent Platform/,
                'error' => 'token generation failed'
              )
            )
          end

          expect { described_class.new.perform(merge_request.id) }
            .not_to trigger_internal_events('auto_assign_reviewers')
        end
      end
    end
  end
end
