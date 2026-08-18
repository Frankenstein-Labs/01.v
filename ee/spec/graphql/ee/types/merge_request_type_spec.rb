# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MergeRequest'], factory_default: :keep, feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:namespace) { create_default(:namespace).freeze }
  let_it_be(:security_orchestration_policy_configuration) { create_default(:security_orchestration_policy_configuration) }
  let_it_be(:blocking_project) { create(:project) }

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :approvals_required, :merge_train_car, :merge_trains_count, :merge_train_index,
      :approval_state, :finding_reports_comparer, :policy_bypass_statuses
    ).at_least
  end

  it { expect(described_class).to have_graphql_field(:approved, complexity: 2, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:approvals_left, complexity: 2, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:has_security_reports, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:security_reports_up_to_date_on_target_branch, calls_gitaly?: true) }
  it { expect(described_class).to have_graphql_field(:suggested_reviewers) }
  it { expect(described_class).to have_graphql_field(:blocking_merge_requests) }
  it { expect(described_class).to have_graphql_field(:merge_request_diffs) }
  it { expect(described_class).to have_graphql_field(:policy_violations) }
  it { expect(described_class).to have_graphql_field(:policies_overriding_approval_settings) }
  it { expect(described_class).to have_graphql_field(:change_requesters) }
  it { expect(described_class).to have_graphql_field(:policy_bypass_statuses) }
  it { expect(described_class).to have_graphql_field(:duo_workflows) }
  it { expect(described_class).to have_graphql_field(:duo_workflow_links) }

  shared_context 'with a merge train' do
    let_it_be(:project, freeze: false) { create(:project, :public) }
    let_it_be(:merge_request) { create(:merge_request, :on_train, target_project: project, source_project: project) }
    let_it_be(:current_user) { create :admin }
  end

  shared_context 'with a merge train and merge trains enabled' do
    include_context 'with a merge train'

    before do
      allow(project).to receive(:merge_trains_enabled?).and_return(true)
    end
  end

  describe '#merge_train_car', feature_category: :merge_trains do
    subject(:associated_merge_train_car) { resolve_field(:merge_train_car, merge_request, current_user: current_user) }

    context 'when merge trains are disabled' do
      include_context 'with a merge train'

      it 'is null' do
        expect(associated_merge_train_car).to be_nil
      end
    end

    context 'when merge trains are enabled' do
      include_context 'with a merge train and merge trains enabled'

      it 'returns a merge train car belonging to the merge request' do
        expect(associated_merge_train_car).to be_an_instance_of MergeTrains::Car
        expect(associated_merge_train_car.id).to eq merge_request.merge_train_car.id
      end
    end
  end

  describe '#merge_trains_count', feature_category: :merge_trains do
    subject(:resulting_count) { resolve_field(:merge_trains_count, merge_request, current_user: current_user) }

    context 'when merge trains are disabled' do
      include_context 'with a merge train'

      it 'the count is null' do
        expect(resulting_count).to be_nil
      end
    end

    context 'when merge trains are enabled' do
      include_context 'with a merge train and merge trains enabled'

      it 'gets the count' do
        expect(resulting_count).to be 1
      end
    end
  end

  describe '#merge_train_index', feature_category: :merge_trains do
    subject(:resulting_index) { resolve_field(:merge_train_index, merge_request, current_user: current_user) }

    context 'when merge trains are disabled' do
      include_context 'with a merge train'

      it 'the count is null' do
        expect(resulting_index).to be_nil
      end
    end

    context 'when merge trains are enabled' do
      include_context 'with a merge train and merge trains enabled'

      it 'gets the count' do
        expect(resulting_index).to be_zero
      end
    end
  end

  shared_examples_for 'avoids N+1 queries' do
    specify do
      GitlabSchema.execute(query, context: { current_user: user })

      # Clear batch loader cache to ensure there's no N+1 if batch loading isn't cached.
      BatchLoader::Executor.clear_current

      control = ActiveRecord::QueryRecorder.new { GitlabSchema.execute(query, context: { current_user: user }) }

      create_additional_resources

      # Clear batch loader cache to ensure there's no N+1 if batch loading isn't cached.
      BatchLoader::Executor.clear_current

      # +2 as we do extra queries for:
      # MergeRequests::Mergeability::CheckSecurityPolicyViolationService
      # MergeRequests::Mergeability::CheckPathLocksService
      # MergeRequest#policy_approval_settings
      expect { GitlabSchema.execute(query, context: { current_user: user }) }.not_to exceed_query_limit(control).with_threshold(7)
    end
  end

  shared_examples_for 'avoids N+1 queries related to approval rules' do
    describe 'avoids N+1 queries with secury scan result' do
      before do
        setup_security_scan_result(merge_request)
      end

      it_behaves_like 'avoids N+1 queries' do
        let(:create_additional_resources) do
          mr_1 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-2'
          )

          create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-3'
          )

          mr_3 = create(
            :merge_request,
            source_project: project
          )

          setup_security_scan_result(mr_1)
          setup_security_scan_result(mr_3)

          # Simulate a merged MR
          mr_3.mark_as_merged!
        end
      end
    end

    describe 'avoids N+1 queries with approvals' do
      before do
        setup_approval_rules(merge_request)
      end

      it_behaves_like 'avoids N+1 queries' do
        let(:create_additional_resources) do
          mr_1 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-2'
          )

          create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-3'
          )

          mr_3 = create(
            :merge_request,
            source_project: project
          )

          setup_approval_rules(mr_1)
          setup_approval_rules(mr_3)

          # Simulate a merged MR
          mr_3.mark_as_merged!
        end
      end
    end

    describe 'avoids N+1 queries with mr diff commits' do
      before do
        setup_mr_diff_commit(merge_request)
      end

      it_behaves_like 'avoids N+1 queries' do
        let(:create_additional_resources) do
          mr_1 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-2'
          )

          mr_2 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-3'
          )

          mr_3 = create(
            :merge_request,
            source_project: project
          )

          setup_mr_diff_commit(mr_1)
          setup_mr_diff_commit(mr_2)
          setup_mr_diff_commit(mr_3)

          # Simulate a merged MR
          mr_3.mark_as_merged!
        end
      end
    end

    describe 'avoids N+1 queries with blocking mrs' do
      it_behaves_like 'avoids N+1 queries' do
        before do
          setup_blocking_mrs(merge_request)
        end

        let(:create_additional_resources) do
          mr_1 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-2'
          )

          mr_2 = create(
            :merge_request,
            source_project: project,
            source_branch: 'source-branch-3'
          )

          mr_3 = create(
            :merge_request,
            source_project: project
          )
          setup_blocking_mrs(mr_1)
          setup_blocking_mrs(mr_2)
          setup_blocking_mrs(mr_3)

          mr_3.mark_as_merged!
        end
      end
    end

    def setup_blocking_mrs(merge_request)
      blocking_mr = create(:merge_request, :skip_diff_creation, :unique_branches,
        source_project: blocking_project,
        target_project: blocking_project)
      create(:merge_request_block, blocked_merge_request: merge_request, blocking_merge_request: blocking_mr)
    end

    def setup_security_scan_result(merge_request)
      policy = create(:scan_result_policy_read, project: project)

      create(:report_approver_rule, :scan_finding, merge_request: merge_request,
        scan_result_policy_read: policy, name: 'Policy 1')

      create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
        scan_result_policy_read: policy, violation_data: nil)
    end

    def setup_mr_diff_commit(merge_request)
      user = create(:user)
      mr_diff_commit_user = create(:merge_request_diff_commit_user, email: user.email)

      create(
        :merge_request_diff_commit,
        merge_request_diff: merge_request.merge_request_diff,
        commit_author: mr_diff_commit_user,
        committer: mr_diff_commit_user
      )
    end

    def setup_approval_rules(merge_request)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_1, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_2, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_3, users: users, groups: groups)
      create(:approval_merge_request_rule, merge_request: merge_request, approval_project_rule: approval_project_rule_4, users: users, groups: groups)
      create(:any_approver_rule, merge_request: merge_request)
      create(:code_owner_rule, merge_request: merge_request, users: users, groups: groups)
      create(:report_approver_rule, merge_request: merge_request, users: users, groups: groups)

      create(:approval, merge_request: merge_request, user: users.last)
      create(:approval, merge_request: merge_request, user: groups.last.members.last.user)
    end
  end

  shared_examples_for 'field with approval rules related check' do
    let_it_be(:user) { project.owner }
    let_it_be(:users, freeze: false) { create_list(:user, 2) }
    let_it_be(:groups, freeze: false) { create_list(:group, 2) }

    let_it_be(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        source_branch: 'source-branch-1'
      )
    end

    let_it_be(:protected_branches) { create_list(:protected_branch, 2, project: project) }

    let_it_be(:approval_project_rule_1, freeze: false) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups
      )
    end

    let_it_be(:approval_project_rule_2) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups
      )
    end

    let_it_be(:approval_project_rule_3) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups,
        protected_branches: protected_branches
      )
    end

    let_it_be(:approval_project_rule_4) do
      create(
        :approval_project_rule,
        project: project,
        users: users,
        groups: groups,
        protected_branches: protected_branches
      )
    end

    before_all do
      users.each do |user|
        project.add_maintainer(user)
      end

      groups.each do |group|
        users = create_list(:user, 2)

        group.add_members(users, GroupMember::MAINTAINER)
      end
    end

    before do
      stub_licensed_features(
        merge_request_approvers: true,
        multiple_approval_rules: true,
        blocking_merge_requests: true
      )
    end

    it_behaves_like 'avoids N+1 queries related to approval rules'

    context 'when overriding approvers is disabled' do
      before do
        project.update!(disable_overriding_approvers_per_merge_request: true)
      end

      it_behaves_like 'avoids N+1 queries related to approval rules'
    end
  end

  describe '#mergeable' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                mergeable
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end

  describe '#approved' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                approved
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end

  describe '#detailed_merge_status' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                detailedMergeStatus
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end

  describe '#mergeability_checks' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                mergeabilityChecks {
                  status
                }
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end

  describe '#approval_state' do
    let_it_be_with_reload(:project) { create(:project, :public) }

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                approvalState {
                  rules {
                    id
                    approved
                    approvalsRequired
                    name
                    type
                  }
                }
              }
            }
          }
        }
      )
    end

    it_behaves_like 'field with approval rules related check'
  end

  describe '#change_requesters' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project, freeze: false) { create(:project, :public) }
    let_it_be(:merge_request) { create(:merge_request, target_project: project, source_project: project) }
    let_it_be(:requested_change) do
      create(:merge_request_requested_changes, merge_request: merge_request, project: merge_request.project,
        user: user)
    end

    let(:query) do
      %(
        query {
          project(fullPath: "#{project.full_path}") {
            mergeRequests {
              nodes {
                changeRequesters {
                  nodes {
                    id
                  }
                }
              }
            }
          }
        }
      )
    end

    subject(:requested_changes) do
      result = GitlabSchema.execute(query, context: { current_user: user })

      graphql_dig_at(result.to_h, :data, :project, :merge_requests, :nodes, 0, :change_requesters, :nodes)
    end

    context 'when project has incorrect license' do
      before do
        stub_licensed_features(requested_changes_block_merge_request: false)
      end

      it 'returns nil' do
        expect(requested_changes).to be_nil
      end
    end

    context 'when project has correct license' do
      before do
        stub_licensed_features(requested_changes_block_merge_request: true)
      end

      it 'returns requested change user' do
        expect(requested_changes).to contain_exactly({ "id" => user.to_gid.to_s })
      end

      it 'avoids N+1 queries' do
        # Warm up table schema and other data
        GitlabSchema.execute(query, context: { current_user: user })

        control = ActiveRecord::QueryRecorder.new { GitlabSchema.execute(query, context: { current_user: user }) }

        mr = create(:merge_request, :unique_branches, target_project: project, source_project: project)
        create(:merge_request_requested_changes, merge_request: mr, project: mr.project,
          user: create(:user))

        # Warm up table schema and other data
        GitlabSchema.execute(query, context: { current_user: user })

        expect { GitlabSchema.execute(query, context: { current_user: user }) }.not_to exceed_query_limit(control)
      end
    end

    describe '#squash_read_only' do
      let_it_be(:project, freeze: false) { create(:project, :public, :repository) }
      let_it_be(:squash_option) { create :branch_rule_squash_option, squash_option: 'never', project: project }
      let_it_be(:merge_request) { create :merge_request, target_branch: squash_option.protected_branch.name, source_project: project, target_project: project }
      let(:query) do
        %(
          query {
            project(fullPath: "#{project.full_path}") {
              mergeRequests {
                nodes {
                  squashReadOnly
                }
              }
            }
          }
        )
      end

      it 'returns squash option' do
        result = GitlabSchema.execute(query, context: { current_user: create(:user) })
        expect(result.dig('data', 'project', 'mergeRequests', 'nodes', 0, 'squashReadOnly')).to be(true)
      end

      it 'avoids N+1 queries' do
        # Warm up table schema and other data
        GitlabSchema.execute(query, context: { current_user: user })

        control = ActiveRecord::QueryRecorder.new { GitlabSchema.execute(query, context: { current_user: user }) }

        other_squash_option = create(:branch_rule_squash_option, squash_option: 'never', project: project)
        create :merge_request, target_branch: other_squash_option.protected_branch.name, source_project: project, target_project: project

        # Warm up table schema and other data
        GitlabSchema.execute(query, context: { current_user: user })

        expect { GitlabSchema.execute(query, context: { current_user: user }) }.not_to exceed_query_limit(control)
      end
    end
  end
end
