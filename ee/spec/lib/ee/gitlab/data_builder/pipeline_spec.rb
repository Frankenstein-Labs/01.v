# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::DataBuilder::Pipeline, feature_category: :continuous_integration do
  let_it_be_with_reload(:project) { create(:project, :public, :small_repo) }

  describe '.build' do
    shared_examples_for 'avoids N+1 queries' do
      specify do
        described_class.build(pipeline.reload)

        control = ActiveRecord::QueryRecorder.new { described_class.build(pipeline.reload) }

        create_additional_resources

        expect { described_class.build(pipeline.reload) }
          .not_to exceed_query_limit(control).with_threshold(2)
      end
    end

    shared_examples_for 'avoids N+1 queries related to approval rules' do
      describe 'avoids N+1 queries with secury scan result' do
        before do
          setup_security_scan_result(merge_request)
        end

        it_behaves_like 'avoids N+1 queries' do
          let(:create_additional_resources) do
            setup_security_scan_result(merge_request)
          end
        end
      end

      describe 'avoids N+1 queries with approvals' do
        before do
          setup_approval_rules(merge_request)

          setup_approvals(
            merge_request,
            users.first,
            groups.first.members.last.user
          )
        end

        it_behaves_like 'avoids N+1 queries' do
          let(:create_additional_resources) do
            setup_approval_rules(merge_request)

            setup_approvals(
              merge_request,
              users.last,
              groups.last.members.last.user
            )
          end
        end

        context 'when MR is merged' do
          it_behaves_like 'avoids N+1 queries' do
            let(:create_additional_resources) do
              setup_approval_rules(merge_request)

              setup_approvals(
                merge_request,
                users.last,
                groups.last.members.last.user
              )

              merge_request.mark_as_merged!
            end
          end
        end
      end

      def setup_security_scan_result(merge_request)
        policy = create(:scan_result_policy_read, project: project)

        create(:report_approver_rule, :scan_finding, merge_request: merge_request,
          scan_result_policy_read: policy)

        create(:scan_result_policy_violation, :running, project: project, merge_request: merge_request,
          scan_result_policy_read: policy, violation_data: nil)
      end

      def setup_approval_rules(merge_request)
        create(
          :approval_merge_request_rule,
          merge_request: merge_request,
          approval_project_rule: approval_project_rule_1,
          users: users,
          groups: groups
        )

        create(
          :approval_merge_request_rule,
          merge_request: merge_request,
          approval_project_rule: approval_project_rule_2,
          users: users,
          groups: groups
        )

        create(
          :approval_merge_request_rule,
          merge_request: merge_request,
          approval_project_rule: approval_project_rule_3,
          users: users,
          groups: groups
        )

        create(
          :approval_merge_request_rule,
          merge_request: merge_request,
          approval_project_rule: approval_project_rule_4,
          users: users,
          groups: groups
        )

        create(:code_owner_rule, merge_request: merge_request, users: users, groups: groups)
        create(:report_approver_rule, merge_request: merge_request, users: users, groups: groups)
      end

      def setup_approvals(merge_request, user, group_user)
        create(:approval, merge_request: merge_request, user: user)
        create(:approval, merge_request: merge_request, user: group_user)
      end
    end

    context 'when pipeline has merge request' do
      let_it_be(:user) { project.owner }
      let_it_be(:users, freeze: false) { create_list(:user, 2) }
      let_it_be(:groups, freeze: false) { create_list(:group, 2) }

      let_it_be_with_reload(:merge_request) do
        create(
          :merge_request,
          :with_detached_merge_request_pipeline,
          source_project: project
        )
      end

      let_it_be(:pipeline) { merge_request.all_pipelines.first }
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
          multiple_approval_rules: true
        )
      end

      it_behaves_like 'avoids N+1 queries related to approval rules'

      context 'when overriding approvers is disabled' do
        before do
          project.update!(disable_overriding_approvers_per_merge_request: true)
        end

        it_behaves_like 'avoids N+1 queries related to approval rules'
      end

      context 'when overriding approvers is enabled' do
        before do
          project.update!(disable_overriding_approvers_per_merge_request: false)
        end

        it_behaves_like 'avoids N+1 queries related to approval rules'
      end
    end
  end
end
