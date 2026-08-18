# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User edits MR approval rules with changing project settings/rules', :sidekiq_inline, feature_category: :source_code_management do
  let_it_be_with_reload(:project) { create(:project, :public, :repository) }

  let_it_be(:approver) { create :user, maintainer_of: project }
  let_it_be(:approver2) { create :user, maintainer_of: project }
  let_it_be(:author) { create :user, :with_namespace, maintainer_of: project }

  let!(:protected_branch) { create(:protected_branch, project: project, name: 'some_wildcard') }

  let(:project_approval_rule_name) { 'Project approval rule' }
  let(:mr_approval_rule_name) { 'MR specific approval rule' }

  before do
    stub_licensed_features(
      multiple_approval_rules: true,
      merge_request_approvers: true
    )
  end

  def create_project_rule
    # Simulate POST api/v4/projects/:id/approval_rules
    ApprovalRules::CreateService.new(project, author, {
      name: project_approval_rule_name,
      approvals_required: 1,
      user_ids: [approver.id, approver2.id],
      group_ids: [],
      protected_branch_ids: [],
      applies_to_all_protected_branches: false
    }).execute
  end

  def create_merge_request
    # Simulate MergeRequests::CreationsController#create
    ::MergeRequests::CreateService.new(project: project, current_user: author, params: {
      title: 'Shiny New Merge Request',
      description: 'description',
      assignee_ids: ['0'],
      reviewer_ids: ['0'],
      approval_rules_attributes: [
        { approvals_required: 0, name: '' },
        *project.approval_rules.map(&:to_nested_attributes)
      ],
      milestone_id: '',
      force_remove_source_branch: '1',
      squash: '0',
      lock_version: '0',
      source_project_id: project.id,
      source_branch: 'fix',
      target_project_id: project.id,
      target_branch: 'feature'
    }).execute
  end

  def rule_names_applicable_to_merge_request(merge_request)
    merge_request.approval_state.wrapped_approval_rules.map(&:name)
  end

  def update_merge_request_approval_rules(approval_rule_attributes)
    ::MergeRequests::UpdateService.new(
      project: project,
      current_user: author,
      params: { approval_rules_attributes: approval_rule_attributes }
    ).execute(MergeRequest.last)
  end

  shared_examples_for 'using only merge request level rules' do
    it 'only shows merge request level rules' do
      expect(MergeRequest.last.approval_rules.count).to eq(2)
      rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
      expect(rule_names).to contain_exactly('All Members', mr_approval_rule_name)
    end
  end

  context 'when editing approval rules in merge requests is allowed' do
    before do
      project.update!(disable_overriding_approvers_per_merge_request: false)
    end

    context 'and a merge request is created with an approval rule before a rule is added to the project' do
      before do
        create_merge_request

        # Simulating MergeRequestsController#update
        update_merge_request_approval_rules([
          {
            name: "MR specific approval rule",
            user_ids: [approver.id],
            group_ids: [],
            approvals_required: 1
          }
        ])

        create_project_rule
      end

      it_behaves_like 'using only merge request level rules'

      context 'and then editing approval rules in merge requests is not allowed' do
        before do
          project.update!(disable_overriding_approvers_per_merge_request: true)
        end

        it 'uses only project rules' do
          rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
          expect(rule_names).to contain_exactly(project_approval_rule_name)
        end

        context 'and editing approval rules in merge requests is allowed' do
          before do
            project.update!(disable_overriding_approvers_per_merge_request: false)
          end

          it_behaves_like 'using only merge request level rules'
        end
      end
    end

    context 'and an approval rule is added to the project before a merge request is created' do
      let(:approval_state) { MergeRequest.last.approval_state }

      before do
        create_project_rule
        create_merge_request
      end

      it 'duplicates project rules for the merge request' do
        rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
        expect(rule_names).to contain_exactly('All Members', project_approval_rule_name)
        expect(MergeRequest.last.approval_rules.count).to eq(2)
      end

      context 'and the project level rule number of approvers is updated' do
        before do
          ApprovalRules::UpdateService.new(project.approval_rules.last, author, approvals_required: 2).execute
        end

        it 'does not change the number of approvers for the corresponding MR approval rule' do
          merge_request_rule = MergeRequest.last.approval_rules.find_by(name: project_approval_rule_name)
          expect(merge_request_rule.approvals_required).to eq(1)

          expect(approval_state.wrapped_approval_rules.size).to eq(2)
          expect(approval_state.wrapped_approval_rules.first.rule_type).to eq('any_approver')
          expect(approval_state.wrapped_approval_rules.last.rule_type).to eq('regular')
        end
      end

      context 'and the inherited rule is modified on the merge request' do
        before do
          rule_attributes = MergeRequest.last.approval_rules.order(id: :asc).map do |rule|
            attributes = rule.slice(:id, :name, :approvals_required).symbolize_keys
            attributes[:group_ids] = rule.group_ids
            attributes[:user_ids] = rule.user_ids
            attributes
          end
          rule_attributes.last[:approvals_required] = 3
          update_merge_request_approval_rules(rule_attributes)
        end

        context 'and the project level rule is no longer applicable to the merge request target branch' do
          before do
            ApprovalProjectRule.last.protected_branches << protected_branch
          end

          it 'shows the modified rule' do
            merge_request_rule = MergeRequest.last.approval_rules.find_by(name: project_approval_rule_name)
            expect(merge_request_rule.approvals_required).to eq(3)
            rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)

            expect(rule_names).to contain_exactly('All Members', project_approval_rule_name)
            expect(approval_state.wrapped_approval_rules.size).to eq(2)
            expect(approval_state.wrapped_approval_rules.first.rule_type).to eq('any_approver')
            expect(approval_state.wrapped_approval_rules.last.rule_type).to eq('regular')
          end
        end
      end

      context 'and the project level rule is no longer applicable to the merge request target branch' do
        before do
          ApprovalProjectRule.last.protected_branches << protected_branch
        end

        it 'does not show the merge level rule' do
          expect(MergeRequest.last.approval_rules.exists?(name: project_approval_rule_name)).to be_truthy
          rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
          expect(rule_names).to contain_exactly('All Members')
        end
      end

      context 'and the project level rule is deleted' do
        before do
          # Simulate DELETE api/v4/projects/:id/approval_rules/:approval_rule_id
          rule = project.approval_rules.find_by(name: project_approval_rule_name)
          ApprovalRules::ProjectRuleDestroyService.new(rule, author).execute
        end

        it 'deletes the corresponding merge request level rule' do
          expect(MergeRequest.last.approval_rules.exists?(name: project_approval_rule_name)).to be_falsey
          expect(MergeRequest.last.approval_rules.count).to eq(1)
          rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
          expect(rule_names).to contain_exactly('All Members')
        end
      end
    end
  end

  context 'when editing approval rules in merge requests is not allowed' do
    before do
      project.update!(disable_overriding_approvers_per_merge_request: true)
    end

    context 'and a merge request is created before a project level rule is added' do
      before do
        create_merge_request
        create_project_rule
      end

      it 'the merge requests uses the project level rules' do
        rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
        expect(rule_names).to contain_exactly(project_approval_rule_name)
      end

      context 'and then editing approval rules in merge requests is allowed' do
        before do
          project.update!(disable_overriding_approvers_per_merge_request: false)
        end

        it 'shows project level rules' do
          rule_names = rule_names_applicable_to_merge_request(MergeRequest.last)
          expect(MergeRequest.last.approval_rules.count).to eq(0)
          expect(rule_names).to contain_exactly(project_approval_rule_name)
        end

        context 'and only a merge request approval rule is added' do
          before do
            update_merge_request_approval_rules([
              # This is meaningful to ApprovalRules::ParamsFilteringService#handle_rules
              { name: "", user_ids: [], group_ids: [], approvals_required: 0 },
              {
                name: "MR specific approval rule",
                user_ids: [approver.id],
                group_ids: [],
                approvals_required: 1
              }
            ])
          end

          it_behaves_like 'using only merge request level rules'
        end
      end
    end
  end
end
