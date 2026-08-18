# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::Refresh::ApprovalService, feature_category: :code_review_workflow do
  include ProjectForksHelper
  include UserHelpers

  let(:group) { create(:group) }
  let(:project) do
    create(:project, :repository, namespace: group, approvals_before_merge: 1, reset_approvals_on_push: true)
  end

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
    describe '#update_approvers_for_target_branch_merge_requests' do
      shared_examples_for 'does not refresh the code owner rules' do
        specify do
          expect(::MergeRequests::SyncCodeOwnerApprovalRules).not_to receive(:new)
          execute
        end
      end

      subject(:execute) { service.execute(oldrev, newrev, "refs/heads/master") }

      let(:enable_code_owner) { true }
      let!(:protected_branch) do
        create(:protected_branch, name: 'master', project: project, code_owner_approval_required: true)
      end

      let(:newrev) { TestEnv::BRANCH_SHA['with-codeowners'] }

      before do
        stub_licensed_features(code_owner_approval_required: true, code_owners: enable_code_owner)
      end

      context 'when the feature flags are enabled' do
        context 'when the branch is protected' do
          context 'when code owners file is updated' do
            let(:irrelevant_merge_request) { another_merge_request }
            let(:relevant_merge_request) { merge_request }

            context 'when not on the merge train' do
              it 'refreshes the code owner rules for all relevant merge requests' do
                fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

                expect(::MergeRequests::SyncCodeOwnerApprovalRules)
                  .to receive(:new).with(relevant_merge_request).and_return(fake_refresh_service)
                expect(fake_refresh_service).to receive(:execute)

                expect(::MergeRequests::SyncCodeOwnerApprovalRules)
                  .not_to receive(:new).with(irrelevant_merge_request)

                execute
              end
            end

            context 'when on the merge train' do
              let(:merge_request) do
                create(
                  :merge_request,
                  :on_train,
                  source_project: project,
                  source_branch: source_branch,
                  target_branch: 'master',
                  target_project: project
                )
              end

              it_behaves_like 'does not refresh the code owner rules'
            end
          end

          context 'when code owners file is not updated' do
            let(:newrev) { TestEnv::BRANCH_SHA['after-create-delete-modify-move'] }

            it_behaves_like 'does not refresh the code owner rules'
          end

          context 'when the branch is deleted' do
            let(:newrev) { Gitlab::Git::SHA1_BLANK_SHA }

            it_behaves_like 'does not refresh the code owner rules'
          end

          context 'when the branch is created' do
            let(:oldrev) { Gitlab::Git::SHA1_BLANK_SHA }

            it_behaves_like 'does not refresh the code owner rules'
          end
        end

        context 'when the branch is not protected' do
          let(:protected_branch) { nil }

          it_behaves_like 'does not refresh the code owner rules'
        end
      end

      context 'when code_owners is disabled' do
        let(:enable_code_owner) { false }

        it_behaves_like 'does not refresh the code owner rules'
      end
    end

    describe '#sync_any_merge_request_approval_rules' do
      let(:merge_request_1) { merge_request }
      let(:merge_request_2) { another_merge_request }

      let!(:scan_result_policy_read) { create(:scan_result_policy_read, :targeting_commits, project: project) }

      it 'enqueues SyncAnyMergeRequestApprovalRulesWorker for all merge requests with the same source branch' do
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request_1.id)
        )
        expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).to(
          receive(:perform_async).with(merge_request_2.id)
        )

        execute
      end

      context 'when scan_result_policy_read does not target commits' do
        let!(:scan_result_policy_read) { create(:scan_result_policy_read, project: project) }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end

      context 'without scan_result_policy_read' do
        let!(:scan_result_policy_read) { nil }

        it 'does not enqueue SyncAnyMergeRequestApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncAnyMergeRequestApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe '#sync_unenforceable_approval_rules' do
      shared_examples 'it enqueues the UnenforceablePolicyRulesNotificationWorker' do
        it 'enqueues the expected UnenforceablePolicyRulesNotificationWorker' do
          expect(Security::UnenforceablePolicyRulesNotificationWorker).to(
            receive(:perform_async).with(merge_request.id)
          )

          execute
        end
      end

      shared_examples 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker' do
        it 'does not enqueue the UnenforceablePolicyRulesNotificationWorker' do
          expect(Security::UnenforceablePolicyRulesNotificationWorker).not_to(
            receive(:perform_async).with(merge_request.id)
          )

          execute
        end
      end

      context 'when the merge request has no pipeline' do
        let(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        it_behaves_like 'it enqueues the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request has a pipeline' do
        let(:merge_request) do
          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        it_behaves_like 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request has a pipeline that does not match the diff_head_sha' do
        let!(:stale_pipeline) do
          create(:ee_ci_pipeline,
            project: project,
            ref: merge_request.source_branch,
            sha: 'stale_sha_that_does_not_match',
            merge_requests_as_head_pipeline: [merge_request])
        end

        it_behaves_like 'it enqueues the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when the merge request is created for a different source branch' do
        let(:merge_request) do
          create(:merge_request,
            source_project: project,
            source_branch: 'feature',
            target_branch: 'master',
            target_project: project
          )
        end

        it_behaves_like 'it does not enqueue the UnenforceablePolicyRulesNotificationWorker'
      end

      context 'when there are multiple merge requests for the source branch' do
        let!(:merge_request) do
          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'master',
            target_project: project)
        end

        let!(:another_merge_request) do
          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'test',
            target_project: project)
        end

        it 'does not produce N+1 queries for diff_head_pipeline' do
          control_count = ActiveRecord::QueryRecorder.new do
            execute
          end

          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'markdown',
            target_project: project)

          create(:merge_request,
            :with_head_pipeline,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'conflict-missing-side',
            target_project: project)

          expect do
            described_class.new(project: project, current_user: current_user)
              .execute(oldrev, newrev, "refs/heads/#{source_branch}")
          end.not_to exceed_query_limit(control_count).for_query(/p_ci_pipelines/)
        end
      end
    end

    describe '#sync_preexisting_states_approval_rules' do
      let(:irrelevant_merge_request) { another_merge_request }
      let(:relevant_merge_request) { merge_request }

      let!(:scan_finding_rule) do
        create(:report_approver_rule, :scan_finding, merge_request: relevant_merge_request)
      end

      it 'enqueues SyncPreexistingStatesApprovalRulesWorker' do
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
          receive(:perform_async).with(relevant_merge_request.id)
        )
        expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to(
          receive(:perform_async).with(irrelevant_merge_request.id)
        )

        execute
      end

      context 'with license_finding rule' do
        let!(:license_finding_rule) do
          create(:report_approver_rule, :license_scanning, merge_request: relevant_merge_request)
        end

        it 'enqueues SyncPreexistingStatesApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).to(
            receive(:perform_async).with(relevant_merge_request.id)
          )

          execute
        end
      end

      context 'without scan_finding rule' do
        let!(:scan_finding_rule) { nil }

        it 'does not enqueue SyncPreexistingStatesApprovalRulesWorker' do
          expect(Security::ScanResultPolicies::SyncPreexistingStatesApprovalRulesWorker).not_to receive(:perform_async)

          execute
        end
      end
    end

    describe '#merge_requests_for' do
      it 'does not introduce N+1 queries when processing additional merge requests' do
        merge_request

        control = ActiveRecord::QueryRecorder.new do
          described_class.new(project: project, current_user: current_user)
            .execute(oldrev, newrev, "refs/heads/#{source_branch}")
        end

        another_merge_request
        create(:merge_request,
          source_project: project,
          source_branch: source_branch,
          target_branch: 'markdown',
          target_project: project)

        # Each additional MR adds a fixed number of expected per-MR queries:
        # - merge_request_diff_files SELECT (modified_paths)
        # - approval_merge_request_rules DELETE (delete_outdated_code_owner_rules)
        # - approval_merge_request_rules EXISTS check (sync_preexisting_states)
        expect do
          described_class.new(project: project, current_user: current_user)
            .execute(oldrev, newrev, "refs/heads/#{source_branch}")
        end.not_to exceed_query_limit(control).with_threshold(6)
      end

      it 'preloads associations on loaded merge requests' do
        merge_request

        svc = described_class.new(project: project, current_user: current_user)
        svc.execute(oldrev, newrev, "refs/heads/#{source_branch}")

        source_mrs = svc.send(:merge_requests_for_source_branch)

        source_mrs.each do |mr|
          expect(mr.association(:target_project)).to be_loaded
          expect(mr.association(:latest_merge_request_diff)).to be_loaded
          expect(mr.association(:merge_head_diff)).to be_loaded
          expect(mr.association(:merge_train_car)).to be_loaded
        end
      end

      context 'when syncing code owner approval rules' do
        let(:owner) { create(:user, username: 'default-codeowner') }

        before do
          stub_licensed_features(code_owners: true)
          project.add_maintainer(owner)

          project.repository.create_file(
            owner, 'CODEOWNERS',
            File.read(Rails.root.join("ee/spec/fixtures/codeowners_example")),
            branch_name: 'master', message: 'codeowners'
          )
        end

        it 'does not introduce N+1 queries for code owner syncing with additional merge requests' do
          merge_request

          control = ActiveRecord::QueryRecorder.new do
            described_class.new(project: project, current_user: current_user)
              .execute(oldrev, newrev, "refs/heads/#{source_branch}")
          end

          another_merge_request
          create(:merge_request,
            source_project: project,
            source_branch: source_branch,
            target_branch: 'markdown',
            target_project: project)

          expect do
            described_class.new(project: project, current_user: current_user)
              .execute(oldrev, newrev, "refs/heads/#{source_branch}")
          end.not_to exceed_query_limit(control).with_threshold(6)
        end
      end
    end

    describe '#update_approvers_for_source_branch_merge_requests' do
      let(:owner) { create(:user, username: 'default-codeowner') }
      let(:current_user) { merge_request.author }
      let(:service) { described_class.new(project: project, current_user: current_user) }
      let(:enable_code_owner) { true }
      let(:enable_report_approver_rules) { true }
      let_it_be(:file) do
        File.read(Rails.root.join("ee/spec/fixtures/codeowners_example"))
      end

      before do
        stub_licensed_features(code_owners: enable_code_owner)
        stub_licensed_features(report_approver_rules: enable_report_approver_rules)

        group.add_maintainer(fork_user)
        project.add_maintainer(owner)

        project.repository.create_file(owner, 'CODEOWNERS', file, branch_name: 'test', message: 'codeowners')

        merge_request
        another_merge_request
        forked_merge_request
      end

      it 'gets called in a specific order' do
        expect(service).to receive(:update_approvers_for_source_branch_merge_requests).ordered
        expect(service).to receive(:reset_approvals_for_merge_requests).ordered

        execute
      end

      context "when creating approval_rules", :sidekiq_inline do
        shared_examples_for 'creates an approval rule based on current diff' do
          it "creates expected approval rules" do
            expect(another_merge_request.approval_rules.size).to eq(approval_rules_size)
            expect(another_merge_request.approval_rules.first.rule_type).to eq('code_owner')
          end
        end

        before do
          execute
        end

        context 'with a non-sectional codeowners file' do
          it_behaves_like 'creates an approval rule based on current diff' do
            let(:approval_rules_size) { 3 }
          end
        end

        context 'with a sectional codeowners file' do
          let_it_be(:file) do
            File.read(Rails.root.join("ee/spec/fixtures/sectional_codeowners_example"))
          end

          it_behaves_like 'creates an approval rule based on current diff' do
            let(:approval_rules_size) { 9 }
          end
        end
      end

      context 'when code owners disabled' do
        let(:enable_code_owner) { false }

        it 'does nothing' do
          expect(::Gitlab::CodeOwners).not_to receive(:for_merge_request)

          execute
        end
      end

      context 'when code owners enabled' do
        let(:relevant_merge_requests) { [merge_request, another_merge_request] }

        it 'refreshes the code owner rules for all relevant merge requests' do
          fake_refresh_service = instance_double(::MergeRequests::SyncCodeOwnerApprovalRules)

          relevant_merge_requests.each do |merge_request|
            expect(::MergeRequests::SyncCodeOwnerApprovalRules)
              .to receive(:new).with(merge_request).and_return(fake_refresh_service)
            expect(fake_refresh_service).to receive(:execute)
          end

          execute
        end
      end

      context 'when report_approver_rules enabled, with approval_rule enabled' do
        let(:relevant_merge_requests) { [merge_request, another_merge_request] }

        it 'refreshes the report_approver rules for all relevant merge requests' do
          relevant_merge_requests.each do |merge_request|
            expect_next_instance_of(::MergeRequests::SyncReportApproverApprovalRules, merge_request,
              current_user) do |service|
              expect(service).to receive(:execute)
            end
          end

          execute
        end
      end
    end

    describe '#reset_approvals_for_merge_requests' do
      let_it_be(:user) { create(:user) }

      let(:approver) { create(:user) }
      let(:newrev) { commits.first.id }
      let(:oldrev) { commits.last.id }
      let(:commits) { merge_request.commits }
      let(:forked_merge_request) do
        create(:merge_request,
          source_project: forked_project,
          source_branch: 'master',
          target_branch: 'feature',
          target_project: project)
      end

      let(:forked_project) { fork_project(project, user, repository: true) }
      let(:merge_request) do
        create(:merge_request,
          source_project: project,
          source_branch: 'master',
          target_branch: 'feature',
          target_project: project,
          merge_when_pipeline_succeeds: true,
          merge_user: user)
      end

      before do
        group.add_owner(user)

        merge_request.approvals.create!(user_id: user.id)
        forked_merge_request.approvals.create!(user_id: user.id)

        project.add_developer(approver)

        perform_enqueued_jobs
      end

      context 'when there are closed merge requests' do
        let(:closed_mr_with_approval) do
          create(:merge_request,
            :closed,
            source_project: project,
            source_branch: 'master',
            target_branch: 'feature',
            target_project: project)
        end

        let(:closed_mr_without_approval) do
          create(:merge_request,
            :closed,
            source_project: project,
            source_branch: 'master',
            target_branch: 'test',
            target_project: project)
        end

        before do
          closed_mr_with_approval.approvals.create!(user_id: user.id)
        end

        it 'does not process closed MRs', :sidekiq_inline do
          expect { service.execute(oldrev, newrev, 'refs/heads/master') }
            .to not_change { closed_mr_with_approval.approvals.count }.from(1)
            .and not_change { closed_mr_without_approval.approvals.count }.from(0)
        end

        it 'does not temporarily unapprove closed MRs' do
          service.execute(oldrev, newrev, 'refs/heads/master')

          expect(closed_mr_with_approval.approval_state.temporarily_unapproved?).to be false
          expect(closed_mr_without_approval.approval_state.temporarily_unapproved?).to be false
        end
      end

      def approval_todos(merge_request)
        Todo.where(action: Todo::APPROVAL_REQUIRED, target: merge_request)
      end

      context 'when push to origin repo source branch', :sidekiq_inline do
        it 'resets approvals and does not create approval todos for regular and for merge request' do
          service.execute(oldrev, newrev, 'refs/heads/master')
          reload_mrs

          expect(merge_request.approvals).to be_empty
          expect(forked_merge_request.approvals).not_to be_empty
          expect(approval_todos(merge_request).map(&:user)).to be_empty
          expect(approval_todos(forked_merge_request)).to be_empty
        end

        context "in the time it takes to reset approvals" do
          context 'when use_oldrev_for_approval_reset is enabled' do
            before do
              stub_feature_flags(use_oldrev_for_approval_reset: project)
              allow(MergeRequestResetApprovalsWorker).to receive(:perform_in).and_return(nil)

              service.execute(oldrev, newrev, 'refs/heads/master')
            end

            it "prevents merging" do
              expect(merge_request.approval_state.temporarily_unapproved?).to be_truthy
            end

            it "flags with the short reset TTL, not the long create-flow TTL" do
              ttl = Gitlab::Redis::SharedState.with { |r| r.ttl("mr_#{merge_request.id}_cannot_merge") }

              expect(ttl).to be_within(2).of(ApprovalState::TEMPORARILY_UNAPPROVED_TTL_ON_RESET.to_i)
              expect(ttl).to be < ApprovalState::TEMPORARILY_UNAPPROVED_TTL.to_i
            end

            it "removes the unmergeable flag after the allotted time" do
              merge_request.approval_state.expire_unapproved_key!

              expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
            end

            it 'passes oldrev to the worker' do
              expect(MergeRequestResetApprovalsWorker).to have_received(:perform_in)
                .with(10.seconds, project.id, anything, anything, newrev, oldrev)
            end
          end

          context 'when use_oldrev_for_approval_reset is disabled' do
            before do
              stub_feature_flags(use_oldrev_for_approval_reset: false)
              allow(MergeRequestResetApprovalsWorker).to receive(:perform_in).and_return(nil)

              service.execute(oldrev, newrev, 'refs/heads/master')
            end

            it "prevents merging" do
              expect(merge_request.approval_state.temporarily_unapproved?).to be_truthy
            end

            it "removes the unmergeable flag after the allotted time" do
              merge_request.approval_state.expire_unapproved_key!

              expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
            end

            it 'does not pass oldrev to the worker' do
              expect(MergeRequestResetApprovalsWorker).to have_received(:perform_in)
                .with(10.seconds, project.id, anything, anything, newrev)
            end
          end
        end

        context "with a merge request on a merge train" do
          before do
            allow_next_instance_of(MergeRequest) do |instance|
              allow(instance).to receive(:merge_train_car).and_return(true)
            end
          end

          it "does not add an umergeable flag" do
            expect(merge_request.approval_state.temporarily_unapproved?).to be_falsey
          end
        end
      end

      context 'when push to origin repo target branch' do
        context 'when all MRs to the target branch had diffs' do
          before do
            service.execute(oldrev, newrev, 'refs/heads/feature')
            reload_mrs
          end

          it 'does not reset approvals' do
            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'when push to fork repo source branch' do
        let(:service) { described_class.new(project: forked_project, current_user: user) }

        def refresh
          service.execute(oldrev, newrev, 'refs/heads/master')
          reload_mrs
        end

        context 'when open fork merge request' do
          it 'resets approvals and does not create approval todo in fork', :sidekiq_might_not_need_inline do
            refresh

            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end

        context 'when closed fork merge request' do
          before do
            forked_merge_request.close!
          end

          it 'does not reset approvals', :sidekiq_might_not_need_inline do
            refresh

            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'when push to fork repo target branch' do
        describe 'changes to merge requests' do
          before do
            described_class.new(project: forked_project, current_user: user).execute(oldrev, newrev,
              'refs/heads/feature')
            reload_mrs
          end

          it 'does not reset approvals', :sidekiq_might_not_need_inline do
            expect(merge_request.approvals).not_to be_empty
            expect(forked_merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
            expect(approval_todos(forked_merge_request)).to be_empty
          end
        end
      end

      context 'when push to origin repo target branch after fork project was removed' do
        before do
          forked_project.destroy!
          service.execute(oldrev, newrev, 'refs/heads/feature')
          reload_mrs
        end

        it 'does not reset approvals' do
          expect(merge_request.approvals).not_to be_empty
          expect(forked_merge_request.approvals).not_to be_empty
          expect(approval_todos(merge_request)).to be_empty
          expect(approval_todos(forked_merge_request)).to be_empty
        end
      end

      context 'when resetting approvals if they are enabled', :sidekiq_inline do
        context 'when approvals_before_merge is disabled' do
          before do
            project.update!(approvals_before_merge: 0)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets approvals and does not create approval todo for approver' do
            expect(merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end
        end

        context 'when reset_approvals_on_push is disabled' do
          before do
            project.update!(reset_approvals_on_push: false)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'does not reset approvals' do
            expect(merge_request.approvals).not_to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end

          context 'when enforced by policy' do
            let(:configuration) { create(:security_orchestration_policy_configuration) }

            let(:security_policy) do
              create(:security_policy,
                security_orchestration_policy_configuration: configuration,
                content: { approval_settings: { remove_approvals_with_new_commit: true } })
            end

            let(:approval_policy_rule) do
              create(:approval_policy_rule, security_policy: security_policy)
            end

            let(:scan_result_policy_read) do
              create(
                :scan_result_policy_read,
                :remove_approvals_with_new_commit,
                security_orchestration_policy_configuration: configuration,
                project: project,
                approval_policy_rule: approval_policy_rule)
            end

            let!(:violation) do
              create(
                :scan_result_policy_violation,
                merge_request: merge_request,
                scan_result_policy_read: scan_result_policy_read,
                approval_policy_rule: approval_policy_rule)
            end

            let!(:approval_rule) do
              create(
                :report_approver_rule,
                merge_request: merge_request,
                scan_result_policy_read: scan_result_policy_read)
            end

            it 'resets approvals' do
              service.execute(oldrev, newrev, 'refs/heads/master')

              expect(merge_request.approvals).to be_empty
            end
          end
        end

        context 'when the rebase_commit_sha on the MR matches the pushed SHA' do
          before do
            merge_request.update!(rebase_commit_sha: newrev)
            service.execute(oldrev, newrev, 'refs/heads/master')
            reload_mrs
          end

          it 'resets approvals' do
            expect(merge_request.approvals).to be_empty
            expect(approval_todos(merge_request)).to be_empty
          end
        end

        context 'when there are approvals', :sidekiq_inline do
          context 'when closed merge request' do
            before do
              merge_request.close!
              service.execute(oldrev, newrev, 'refs/heads/master')
              reload_mrs
            end

            it 'does not reset the approvals' do
              expect(merge_request.approvals).not_to be_empty
              expect(approval_todos(merge_request)).to be_empty
            end
          end

          context 'when opened merge request' do
            before do
              service.execute(oldrev, newrev, 'refs/heads/master')
              reload_mrs
            end

            it 'resets the approvals' do
              expect(merge_request.approvals).to be_empty
              expect(approval_todos(merge_request)).to be_empty
            end
          end
        end
      end

      def reload_mrs
        merge_request.reload
        forked_merge_request.reload
      end
    end
  end
end
