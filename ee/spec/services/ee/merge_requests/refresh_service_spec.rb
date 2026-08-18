# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::RefreshService, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include UserHelpers

  let(:group) { create(:group) }
  let(:project) { create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true) }
  let(:forked_project) { fork_project(project, fork_user, repository: true) }

  let(:fork_user) { create(:user) }

  let(:source_branch) { 'between-create-delete-modify-move' }

  let(:merge_request) do
    create(:merge_request,
      source_project: project,
      source_branch: source_branch,
      target_branch: 'master',
      target_project: project)
  end

  let(:another_merge_request) do
    create(:merge_request,
      source_project: project,
      source_branch: source_branch,
      target_branch: 'test',
      target_project: project)
  end

  let(:forked_merge_request) do
    create(:merge_request,
      source_project: forked_project,
      source_branch: source_branch,
      target_branch: 'master',
      target_project: project)
  end

  let(:oldrev) { TestEnv::BRANCH_SHA[source_branch] }
  let(:newrev) { TestEnv::BRANCH_SHA['after-create-delete-modify-move'] } # Pretend source_branch is now updated
  let(:service) { described_class.new(project: project, current_user: current_user) }
  let(:current_user) { merge_request.author }

  subject(:execute) { service.execute(oldrev, newrev, "refs/heads/#{source_branch}") }

  describe '#execute' do
    it 'checks merge train status' do
      expect_next_instance_of(MergeTrains::CheckStatusService, project, current_user) do |service|
        expect(service).to receive(:execute).with(project, source_branch, newrev)
      end

      subject
    end

    it 'calls the approval worker' do
      expect(::MergeRequests::Refresh::ApprovalWorker).to receive(:perform_async).with(
        project.id,
        current_user.id,
        oldrev,
        newrev,
        "refs/heads/#{source_branch}"
      )

      subject
    end

    context 'when branch is deleted' do
      let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

      it 'does not check merge train status' do
        expect(MergeTrains::CheckStatusService).not_to receive(:new)

        subject
      end
    end

    context 'when user has requested changes' do
      before do
        create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
          user: current_user)
      end

      context 'when project does not have the right license' do
        before do
          stub_licensed_features(requested_changes_block_merge_request: false)
        end

        it 'does not call merge_request.destroy_requested_changes' do
          expect { subject }.not_to change { merge_request.requested_changes.count }.from(1)
        end
      end

      context 'when licensed feature is available' do
        before do
          stub_licensed_features(requested_changes_block_merge_request: true)
        end

        context 'when merge_requests_disable_committers_approval is disabled' do
          before do
            project.update!(merge_requests_disable_committers_approval: false)
          end

          it 'does not call merge_request.destroy_requested_changes' do
            expect { subject }.not_to change { merge_request.requested_changes.count }.from(1)
          end
        end

        context 'when merge_requests_disable_committers_approval is enabled' do
          before do
            project.update!(merge_requests_disable_committers_approval: true)
          end

          it 'calls merge_request.destroy_requested_changes' do
            expect { subject }.to change { merge_request.requested_changes.count }.from(1).to(0)
          end

          context 'when user is a reviewer' do
            before do
              create(:merge_request_reviewer, merge_request: merge_request, reviewer: current_user, state: 'reviewed')
              project.add_developer(current_user)
            end

            it 'updates reviewer state to unreviewed' do
              subject

              expect(merge_request.merge_request_reviewers.first).to be_unreviewed
            end
          end
        end
      end
    end

    describe 'schedule_duo_code_review' do
      let(:ai_review_allowed) { true }

      before do
        allow(project)
          .to receive(:auto_duo_code_review_enabled)
          .and_return(auto_duo_code_review)

        allow_next_found_instance_of(MergeRequest) do |mr|
          allow(mr)
            .to receive(:ai_review_merge_request_allowed?)
            .and_return(ai_review_allowed)
        end
      end

      context 'when auto_duo_code_review_enabled is false' do
        let(:auto_duo_code_review) { false }

        it 'does not call ::Llm::ReviewMergeRequestService' do
          expect(Llm::ReviewMergeRequestService).not_to receive(:new)

          subject
        end
      end

      context 'when auto_duo_code_review_enabled is true' do
        let(:auto_duo_code_review) { true }

        before do
          create(:merge_request_diff, merge_request: merge_request, state: :empty)
        end

        context 'when merge request is a draft' do
          let(:merge_request) do
            create(
              :merge_request,
              :draft_merge_request,
              source_project: project,
              source_branch: source_branch,
              target_branch: 'master',
              target_project: project
            )
          end

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            subject
          end
        end

        context 'when previous diff is not empty' do
          before do
            create(:merge_request_diff, merge_request: merge_request)
          end

          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            subject
          end
        end

        context 'when Duo Code Review bot is not assigned as a reviewer' do
          it 'does not call ::Llm::ReviewMergeRequestService' do
            expect(Llm::ReviewMergeRequestService).not_to receive(:new)

            subject
          end
        end

        context 'when Duo Code Review bot is assigned as a reviewer' do
          let(:duo_code_review_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

          before do
            merge_request.reviewers = [duo_code_review_bot]
          end

          context 'when AI review feature is not allowed' do
            let(:ai_review_allowed) { false }

            it 'does not call any review service' do
              expect(Llm::ReviewMergeRequestService).not_to receive(:new)
              expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

              subject
            end
          end

          context 'when AI review feature is allowed' do
            let(:ai_review_allowed) { true }

            context 'with Duo Enterprise using classic flow' do
              let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

              before do
                stub_feature_flags(duo_code_review_dap_internal_users: false)
                create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_enterprise_add_on)
                project.project_setting.update!(duo_features_enabled: true)
              end

              it 'calls legacy ::Llm::ReviewMergeRequestService' do
                expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
                  expect(svc).to receive(:execute)
                end

                subject
              end

              it 'does not call DAP service' do
                allow_next_instance_of(Llm::ReviewMergeRequestService) do |svc|
                  allow(svc).to receive(:execute)
                end

                expect(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService).not_to receive(:new)

                subject
              end

              context 'when the git pusher is different from the MR author' do
                let(:pusher) { create(:user) }

                subject do
                  described_class.new(project: project, current_user: pusher)
                    .execute(oldrev, newrev, "refs/heads/#{source_branch}")
                end

                it 'bills the MR author, not the git pusher' do
                  expect(Llm::ReviewMergeRequestService).to receive(:new)
                    .with(have_attributes(id: merge_request.author_id), merge_request)
                    .and_return(instance_double(Llm::ReviewMergeRequestService, execute: nil))

                  subject
                end
              end
            end

            context 'with DAP flow (Duo Core/Pro or Duo Enterprise with internal flag)' do
              let!(:duo_core_add_on) { create(:gitlab_subscription_add_on, :duo_core) }
              let_it_be(:code_review_foundational_flow) { create(:ai_catalog_item, :with_foundational_flow_reference) }

              before do
                project.project_setting.update!(duo_features_enabled: true, duo_foundational_flows_enabled: true)
                create(:gitlab_subscription_add_on_purchase, :self_managed, add_on: duo_core_add_on)
                allow(current_user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)
                allow(::Gitlab::Llm::StageCheck).to receive(:available?)
                  .with(merge_request.project, :duo_workflow).and_return(true)
                allow(::Ai::Catalog::FoundationalFlow).to receive(:[])
                  .with('code_review/v1')
                  .and_return(
                    instance_double(
                      ::Ai::Catalog::FoundationalFlow, catalog_item: code_review_foundational_flow
                    )
                  )
                create(:ai_catalog_enabled_foundational_flow, :for_namespace, namespace: project.root_ancestor,
                  catalog_item: code_review_foundational_flow)
                allow(Ability).to receive(:allowed?).and_call_original
                allow(Ability).to receive(:allowed?).with(current_user, :create_note, merge_request).and_return(true)
              end

              it 'calls Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService' do
                expect_next_instance_of(
                  Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService,
                  user: current_user,
                  merge_request: merge_request
                ) do |svc|
                  expect(svc).to receive(:execute)
                end

                subject
              end

              it 'does not call legacy Llm::ReviewMergeRequestService' do
                allow_next_instance_of(Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService) do |svc|
                  allow(svc).to receive(:execute)
                end

                expect(Llm::ReviewMergeRequestService).not_to receive(:new)

                subject
              end
            end
          end
        end
      end
    end
  end

  describe '#abort_ff_merge_requests_with_when_pipeline_succeeds' do
    let_it_be(:project) { create(:project, :repository, merge_method: 'ff') }
    let_it_be(:author) { create_user_from_membership(project, :developer) }
    let_it_be(:user) { create(:user) }

    let_it_be_with_refind(:merge_request) do
      create(
        :merge_request,
        author: author,
        source_project: project,
        source_branch: 'feature',
        target_branch: 'master',
        target_project: project,
        auto_merge_enabled: true,
        merge_user: user
      )
    end

    let_it_be(:newrev) do
      project
        .repository
        .create_file(
          user,
          'test1.txt',
          'Test data',
          message: 'Test commit',
          branch_name: 'master'
        )
    end

    let_it_be(:oldrev) do
      project
        .repository
        .commit(newrev)
        .parent_id
    end

    let(:refresh_service) { described_class.new(project: project, current_user: user) }

    before do
      merge_request.auto_merge_strategy = auto_merge_strategy
      merge_request.save!

      refresh_service.execute(oldrev, newrev, 'refs/heads/master')
      merge_request.reload
    end

    context 'with add to merge train when checks pass strategy' do
      let(:auto_merge_strategy) do
        AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_CHECKS_PASS
      end

      it_behaves_like 'maintained merge requests for auto merges'
    end

    context 'with merge train strategy' do
      let(:auto_merge_strategy) { AutoMergeService::STRATEGY_MERGE_TRAIN }

      it_behaves_like 'maintained merge requests for auto merges'
    end
  end
end
