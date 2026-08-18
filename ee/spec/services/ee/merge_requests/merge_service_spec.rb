# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequests::MergeService, feature_category: :source_code_management do
  include NamespaceStorageHelpers
  include GitlabSubscriptions::SubscriptionHelpers

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, :simple) }
  let(:project) { merge_request.project }
  let(:service) { described_class.new(project: project, current_user: user, params: params) }
  let(:params) { { sha: merge_request.diff_head_sha, commit_message: 'Awesome message' } }

  before do
    project.add_maintainer(user)
  end

  describe '#execute' do
    context 'project has exceeded size limit' do
      before do
        project.update_attribute(:repository_size_limit, 5)
        project.statistics.update!(repository_size: 8)
      end

      it 'persists the correct error message' do
        service.execute(merge_request)

        expect(merge_request.merge_error).to eq(
          'This merge request cannot be merged, ' \
          'because this repository has exceeded the allocated storage for your project'
        )
      end
    end

    context 'when the namespace storage limit has been exceeded', :saas do
      let(:namespace) { project.namespace }

      before do
        # Use create_or_replace_subscription because project.add_maintainer (line 15)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(namespace, :premium)
        create(:namespace_root_storage_statistics, namespace: namespace)
        enforce_namespace_storage_limit(namespace)
        set_enforcement_limit(namespace, megabytes: 4)
        set_used_storage(namespace, megabytes: 5)
      end

      it 'persists the correct error message' do
        service.execute(merge_request)

        expect(merge_request.merge_error).to include(
          'Your namespace storage is full. This merge request cannot be merged.'
        )
      end
    end

    context 'when the repository size limit has been exceeded, but the namespace storage limit has not', :saas do
      let(:namespace) { project.namespace }

      before do
        # Use create_or_replace_subscription because project.add_maintainer (line 15)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(namespace, :premium)
        create(:namespace_root_storage_statistics, namespace: namespace)
        enforce_namespace_storage_limit(namespace)
        set_enforcement_limit(namespace, megabytes: 10)
        set_used_storage(namespace, megabytes: 7)

        project.update_attribute(:repository_size_limit, 5)
        project.statistics.update!(repository_size: 6)
      end

      it 'does not set an error message' do
        service.execute(merge_request)

        expect(merge_request.merge_error).to be_nil
      end
    end

    context 'when the namespace storage limit has been exceeded and the merge request is for a subgroup project', :saas do
      let(:group) { create(:group) }
      let(:subgroup) { create(:group, parent: group) }
      let(:project) { create(:project, :repository, group: subgroup) }
      let(:merge_request) { create(:merge_request, :simple, source_project: project) }

      before do
        # Use create_or_replace_subscription because project.add_maintainer (line 15)
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :premium)
        create(:namespace_root_storage_statistics, namespace: group)
        enforce_namespace_storage_limit(group)
        set_enforcement_limit(group, megabytes: 6)
        set_used_storage(group, megabytes: 8)
      end

      it 'persists the correct error message' do
        service.execute(merge_request)

        expect(merge_request.merge_error).to include(
          'Your namespace storage is full. This merge request cannot be merged.'
        )
      end
    end

    context 'when the namespace is over the free user cap limit', :saas do
      let(:namespace) { create(:group_with_plan, :private, plan: :free_plan) }

      before do
        project.update!(namespace: namespace)
        stub_ee_application_setting(dashboard_limit_enabled: true)
      end

      it 'persists the correct error message' do
        service.execute(merge_request)

        expect(merge_request.merge_error).to match(/Your top-level group is over the user limit/)
      end
    end

    context 'when merge request rule exists' do
      let(:approver) { create(:user) }
      let!(:approval_rule) { create :approval_merge_request_rule, merge_request: merge_request, users: [approver] }
      let!(:approval) { create :approval, merge_request: merge_request, user: approver }

      it 'creates approved_approvers' do
        allow(service).to receive(:execute_hooks)

        perform_enqueued_jobs do
          service.execute(merge_request)
        end
        merge_request.reload
        rule = merge_request.approval_rules.first

        expect(merge_request.merged?).to eq(true)
        expect(rule.approved_approvers).to contain_exactly(approver)
      end
    end

    context 'with jira issue enforcement' do
      using RSpec::Parameterized::TableSyntax

      let_it_be(:jira_integration) { create(:jira_integration) }

      subject do
        perform_enqueued_jobs do
          service.execute(merge_request)
        end
      end

      where(:prevent_merge, :issue_specified, :merged) do
        true  | true  | true
        true  | false | false
        false | true  | true
        false | false | true
      end

      with_them do
        before do
          allow(project).to receive(:jira_integration).and_return(jira_integration)
          allow(project).to receive(:prevent_merge_without_jira_issue?).and_return(prevent_merge)
          allow(Atlassian::JiraIssueKeyExtractor).to receive(:has_keys?)
            .with(merge_request.title, merge_request.description, custom_regex: merge_request.project.jira_integration.reference_pattern)
                                                       .and_return(issue_specified)
        end

        it 'sets the correct merged state and raises an error when applicable', :aggregate_failures do
          subject

          expect(merge_request.reload.merged?).to eq(merged)
          expect(merge_request.merge_error).to include('To merge, either the title or description must reference a Jira issue.') unless merged
        end
      end
    end

    context 'with merge train enforcement enabled', :aggregate_failures do
      before do
        stub_licensed_features(merge_pipelines: true, merge_trains: true)
        project.update!(approvals_before_merge: 0)
        project.ci_cd_settings.update!(
          merge_pipelines_enabled: true,
          merge_trains_enabled: true,
          merge_train_enforcement: :enforce_for_all_users
        )
      end

      it 'refuses a direct merge and does not merge' do
        service.execute(merge_request)

        expect(merge_request.reload).not_to be_merged
        expect(merge_request.merge_error).to include('merge train')
      end

      context 'when merging via the merge train (internal param)' do
        let(:params) { { sha: merge_request.diff_head_sha, merging_via_merge_train: true } }

        it 'allows the merge' do
          service.execute(merge_request)

          expect(merge_request.reload).to be_merged
        end
      end
    end

    context 'when skip_merge_train is true', :aggregate_failures do
      subject { service.execute(merge_request) }

      let(:newest_car) { MergeTrains::Car.last }
      let(:train)      { MergeTrains::Train.new(merge_request.project_id, merge_request.target_branch) }
      let(:params)     { { sha: merge_request.diff_head_sha, commit_message: 'A message', skip_merge_train: true } }

      context 'with merge_trains_skip_merge_train_allowed ProjectCiCdSetting enabled' do
        before do
          stub_licensed_features(merge_pipelines: true, merge_trains: true)

          project.update!(approvals_before_merge: 0)
          project.ci_cd_settings.update!(
            merge_pipelines_enabled: true,
            merge_trains_enabled: true,
            merge_trains_skip_train_allowed: true
          )
        end

        it 'creates a new merged Car record and adds the revision to the train history' do
          expect { subject }.to change { MergeTrains::Car.count }.by(1)
          expect(newest_car.merge_request).to eq(merge_request)
          expect(newest_car).to be_skip_merged

          expect(train.sha_exists_in_history?(merge_request.merge_commit_sha)).to be_truthy
        end
      end

      context 'with merge_trains_skip_merge_train_allowed ProjectCiCdSetting disabled' do
        before do
          project.ci_cd_settings.update!(merge_trains_skip_train_allowed: false)
        end

        it 'does not create any new Car record or add to the train revision history' do
          expect { subject }.not_to change { MergeTrains::Car.count }
          expect(merge_request).to be_merged
          expect(train.sha_exists_in_history?(merge_request.merge_commit_sha)).to be_falsy
        end
      end

      context 'when the merge_train_skip_trains feature flag is disabled' do
        before do
          stub_feature_flags(merge_trains_skip_train: false)
        end

        it 'does not create any new Car record or add to the train revision history' do
          expect { subject }.not_to change { MergeTrains::Car.count }
          expect(merge_request).to be_merged
          expect(train.sha_exists_in_history?(merge_request.merge_commit_sha)).to be_falsy
        end
      end
    end
  end

  # Final approval re-check performed inside the merge lock.
  # See https://gitlab.com/gitlab-org/gitlab/-/issues/604469
  describe 'approval re-check inside the merge lock' do
    context 'when approvals are required' do
      before do
        allow(merge_request).to receive(:approval_feature_available?).and_return(true)
        allow(merge_request).to receive(:reset_approval_cache!)
      end

      # The approval is revoked in the window between #validate! (pre-lock) and the
      # git write. #validate! is stubbed so the in-lock re-check is the only guard
      # under test. The re-check raises inside MergeRequest#in_locked_state, whose
      # ensure block unlocks the MR, so a failed re-check must not leave it locked.
      context 'when the approval is revoked before the lock is taken' do
        before do
          allow(service).to receive(:validate!)
          allow(merge_request).to receive(:approved?).and_return(false)
        end

        it 'refreshes the cache, aborts the merge, and leaves the MR unlocked', :aggregate_failures do
          expect(merge_request).to receive(:reset_approval_cache!)

          service.execute(merge_request)
          merge_request.reload

          expect(merge_request).not_to be_merged
          expect(merge_request).not_to be_locked
          expect(merge_request.merge_error).to eq('Merge request is not approved')
        end
      end

      context 'when the merge request is still approved' do
        it 'refreshes the cache and completes the merge', :aggregate_failures do
          expect(merge_request).to receive(:reset_approval_cache!)

          service.execute(merge_request)

          expect(merge_request.reload).to be_merged
        end
      end
    end

    context 'when approvals are not required' do
      before do
        allow(merge_request).to receive(:approval_feature_available?).and_return(false)
      end

      it 'skips the approval re-check and completes the merge', :aggregate_failures do
        expect(merge_request).not_to receive(:reset_approval_cache!)

        service.execute(merge_request)

        expect(merge_request.reload).to be_merged
      end
    end
  end

  it_behaves_like 'merge validation hooks', persisted: true
end
