# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::GoalTemplates::Developer, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  let(:user_input) { 'Please help me with this task' }
  let(:triggered_by_username) { 'john_doe' }

  describe '.resolve' do
    context 'with init_project_context event type' do
      it 'returns a goal interpolated with project full path and default branch' do
        result = described_class.resolve(
          event_type: :init_project_context,
          resource: project,
          user_input: nil
        )

        expect(result).to include(project.full_path)
        expect(result).to include(project.default_branch_or_main)
      end

      it 'includes instructions to create a merge request' do
        result = described_class.resolve(
          event_type: :init_project_context,
          resource: project,
          user_input: nil
        )

        expect(result).to include('draft merge request')
      end

      it 'stays within the workflow goal size limit' do
        result = described_class.resolve(
          event_type: :init_project_context,
          resource: project,
          user_input: nil
        )

        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'with improve_ci event type' do
      it 'returns a goal interpolated with project full path and default branch' do
        result = described_class.resolve(
          event_type: :improve_ci,
          resource: project,
          user_input: nil
        )

        expect(result).to include(project.full_path)
        expect(result).to include(project.default_branch_or_main)
      end

      it 'includes instructions to review .gitlab-ci.yml' do
        result = described_class.resolve(
          event_type: :improve_ci,
          resource: project,
          user_input: nil
        )

        expect(result).to include('.gitlab-ci.yml')
      end

      it 'includes instructions to open a draft merge request' do
        result = described_class.resolve(
          event_type: :improve_ci,
          resource: project,
          user_input: nil
        )

        expect(result).to include('--draft')
      end

      it 'stays within the workflow goal size limit' do
        result = described_class.resolve(
          event_type: :improve_ci,
          resource: project,
          user_input: nil
        )

        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'with init_execution_env event type' do
      it 'returns an interpolated goal covering all required content', :aggregate_failures do
        result = described_class.resolve(
          event_type: :init_execution_env,
          resource: project,
          user_input: nil
        )

        expect(result).to include(project.full_path)
        expect(result).to include(project.default_branch_or_main)
        expect(result).to include('.gitlab/duo/agent-config.yml')
        expect(result).to include('image')
        expect(result).to include('setup_script')
        expect(result).to include('cache')
        expect(result).to include('network_policy')
        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'with init_mr_review_instructions event type' do
      it 'returns an interpolated goal covering all required content', :aggregate_failures do
        result = described_class.resolve(
          event_type: :init_mr_review_instructions,
          resource: project,
          user_input: nil
        )

        expect(result).to include(project.full_path)
        expect(result).to include(project.default_branch_or_main)
        expect(result).to include('.gitlab/duo/mr-review-instructions.yaml')
        expect(result).to include('fileFilters')
        expect(result).to include('draft merge request')
        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'with init_codeowners event type' do
      it 'returns an interpolated goal covering all required content', :aggregate_failures do
        result = described_class.resolve(
          event_type: :init_codeowners,
          resource: project,
          user_input: nil
        )

        expect(result).to include(project.full_path)
        expect(result).to include(project.default_branch_or_main)
        expect(result).to include('CODEOWNERS')
        expect(result).to include('.gitlab/duo/')
        expect(result).to include('draft merge request')
        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'with init_chat_rules event type' do
      it 'returns an interpolated goal covering all required content', :aggregate_failures do
        result = described_class.resolve(
          event_type: :init_chat_rules,
          resource: project,
          user_input: nil
        )

        expect(result).to include(project.full_path)
        expect(result).to include(project.default_branch_or_main)
        expect(result).to include('.gitlab/duo/chat-rules.md')
        expect(result).to include('AGENTS.md')
        expect(result).to include('draft merge request')
        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'with mention event type' do
      let(:params) { { note_id: 42, triggered_by_username: triggered_by_username } }

      it 'returns a goal from the mention template with conversation context' do
        result = described_class.resolve(
          event_type: :mention, resource: issue, user_input: user_input, params: params
        )

        expect(result).to include('<conversation>')
        expect(result).to include(user_input)
        expect(result).to include('<gitlab_context>')
      end

      it 'includes the triggering username in the goal', :aggregate_failures do
        result = described_class.resolve(
          event_type: :mention, resource: issue, user_input: user_input, params: params
        )

        expect(result).to include("@#{triggered_by_username} is talking to you")
        expect(result).to include("Reply to @#{triggered_by_username}")
        expect(result).to include("assign @#{triggered_by_username} to any merge request")
      end

      it 'includes the correct resource name for a merge request' do
        result = described_class.resolve(
          event_type: :mention, resource: merge_request, user_input: user_input, params: params
        )

        expect(result).to include("talking to you in a conversation on this merge request")
      end

      it 'handles missing triggered_by_username gracefully' do
        result = described_class.resolve(
          event_type: :mention, resource: issue, user_input: user_input, params: { note_id: 42 }
        )

        expect(result).to include('@ is talking to you')
      end
    end

    context 'with assign event type' do
      let(:params) { { triggered_by_username: triggered_by_username } }

      it 'returns the issue template for an Issue' do
        result = described_class.resolve(
          event_type: :assign, resource: issue, user_input: user_input, params: params
        )

        expect(result).to include("@#{triggered_by_username} assigned you to solve the following issue:")
        expect(result).to include(Gitlab::UrlBuilder.build(issue))
        expect(result).to include("@mention @#{triggered_by_username} in a comment on the issue")
      end

      it 'returns the work item template with correct resource name for a WorkItem' do
        work_item = create(:work_item, project: project)
        result = described_class.resolve(
          event_type: :assign, resource: work_item, user_input: user_input, params: params
        )

        expect(result).to include("@#{triggered_by_username} assigned you to solve the following work item:")
        expect(result).to include(Gitlab::UrlBuilder.build(work_item))
      end

      it 'returns the MR assign template for a MergeRequest' do
        result = described_class.resolve(
          event_type: :assign, resource: merge_request, user_input: user_input, params: params
        )

        expect(result).to include("@#{triggered_by_username} assigned you to a merge request:")
        expect(result).to include('Fetch the merge request details, its diffs, pipeline status')
        expect(result).to include(Gitlab::UrlBuilder.build(merge_request))
        expect(result).to include("@mention @#{triggered_by_username} in a comment")
      end
    end

    context 'with assign_reviewer event type' do
      let(:params) { { triggered_by_username: triggered_by_username } }

      it 'returns the MR review template for a MergeRequest' do
        result = described_class.resolve(
          event_type: :assign_reviewer, resource: merge_request, user_input: user_input, params: params
        )

        expect(result).to include("@#{triggered_by_username} requested your review on a merge request:")
        expect(result).to include(Gitlab::UrlBuilder.build(merge_request))
        expect(result).to include("@mention @#{triggered_by_username} in a comment")
      end
    end

    context 'with merge_request event type' do
      it 'returns the merged merge request template', :aggregate_failures do
        result = described_class.resolve(
          event_type: :merge_request, resource: merge_request, user_input: user_input,
          params: { action: 'merged', session_ids: [123, 456] }
        )

        expect(result).to include('has just been merged')
        expect(result).to include(Gitlab::UrlBuilder.build(merge_request))
        expect(result).to include('session IDs: 123, 456')
        expect(result).to include('persistent repo memory')
        expect(result).to include("chore/distill-agent-memory-mr-#{merge_request.iid}")
        expect(result.bytesize).to be < 16.kilobytes
      end
    end

    context 'when resource is nil' do
      it 'raises ArgumentError' do
        expect do
          described_class.resolve(
            event_type: :assign, resource: nil, user_input: user_input
          )
        end.to raise_error(ArgumentError, /resource must not be nil/)
      end
    end

    context 'with unsupported event type' do
      it 'raises ArgumentError' do
        expect do
          described_class.resolve(
            event_type: :pipeline_hooks, resource: issue, user_input: user_input
          )
        end.to raise_error(ArgumentError, /Unsupported event type.*:pipeline_hooks/)
      end
    end

    context 'when user input contains format string sequences' do
      let(:malicious_input) { 'Fix %{resource_url} and %{unknown_key} please' }
      let(:params) { { note_id: 42, triggered_by_username: triggered_by_username } }

      it 'preserves literal %{...} sequences in user input without raising' do
        result = described_class.resolve(
          event_type: :mention, resource: issue, user_input: malicious_input, params: params
        )

        expect(result).to include('%{unknown_key}')
        expect(result).to include('<conversation>')
        expect(result).to include(malicious_input)
      end

      it 'does not let user input substitute resource_url in template vars' do
        result = described_class.resolve(
          event_type: :mention, resource: issue, user_input: malicious_input, params: params
        )

        # The %{resource_url} in user input should remain literal, not be double-substituted
        expect(result).to include("Fix %{resource_url} and %{unknown_key} please")
      end
    end
  end

  describe '.handler_for' do
    it 'returns Mention for :mention' do
      expect(described_class.handler_for(:mention, issue))
        .to eq(Ai::Catalog::GoalTemplates::Developer::Mention)
    end

    it 'returns AssignIssue for :assign with non-MR resource' do
      expect(described_class.handler_for(:assign, issue)).to eq(Ai::Catalog::GoalTemplates::Developer::AssignIssue)
    end

    it 'returns AssignMergeRequest for :assign with MergeRequest' do
      expect(described_class.handler_for(:assign, merge_request))
        .to eq(Ai::Catalog::GoalTemplates::Developer::AssignMergeRequest)
    end

    it 'returns AssignMergeRequestReview for :assign_reviewer' do
      expect(described_class.handler_for(:assign_reviewer, merge_request))
        .to eq(Ai::Catalog::GoalTemplates::Developer::AssignMergeRequestReview)
    end

    it 'returns MergedMergeRequest for the merged :merge_request action' do
      expect(described_class.handler_for(:merge_request, merge_request, { action: 'merged' }))
        .to eq(Ai::Catalog::GoalTemplates::Developer::MergedMergeRequest)
    end

    it 'raises for a merge_request action other than merged' do
      expect { described_class.handler_for(:merge_request, merge_request, { action: 'approved' }) }
        .to raise_error(ArgumentError, /Unsupported merge request action/)
    end

    it 'raises for a merge_request event with no action' do
      expect { described_class.handler_for(:merge_request, merge_request) }
        .to raise_error(ArgumentError, /Unsupported merge request action/)
    end

    it 'returns InitProjectContext for :init_project_context' do
      expect(described_class.handler_for(:init_project_context, project))
        .to eq(Ai::Catalog::GoalTemplates::Developer::InitProjectContext)
    end

    it 'returns ImproveCi for :improve_ci' do
      expect(described_class.handler_for(:improve_ci, project))
        .to eq(Ai::Catalog::GoalTemplates::Developer::ImproveCi)
    end

    it 'returns InitExecutionEnv for :init_execution_env' do
      expect(described_class.handler_for(:init_execution_env, project))
        .to eq(Ai::Catalog::GoalTemplates::Developer::InitExecutionEnv)
    end

    it 'returns InitMrReviewInstructions for :init_mr_review_instructions' do
      expect(described_class.handler_for(:init_mr_review_instructions, project))
        .to eq(Ai::Catalog::GoalTemplates::Developer::InitMrReviewInstructions)
    end

    it 'returns InitChatRules for :init_chat_rules' do
      expect(described_class.handler_for(:init_chat_rules, project))
        .to eq(Ai::Catalog::GoalTemplates::Developer::InitChatRules)
    end

    it 'raises ArgumentError for unknown event type' do
      expect { described_class.handler_for(:unknown, issue) }
        .to raise_error(ArgumentError, /Unsupported event type/)
    end
  end

  describe '.resource_display_name' do
    it 'returns "merge request" for MergeRequest' do
      expect(described_class.resource_display_name(merge_request)).to eq('merge request')
    end

    it 'returns "issue" for Issue' do
      expect(described_class.resource_display_name(issue)).to eq('issue')
    end

    it 'returns "work item" for WorkItem' do
      resource = build(:work_item, project: project)
      expect(described_class.resource_display_name(resource)).to eq('work item')
    end

    it 'returns a humanized fallback for unknown resource types' do
      resource = build(:project)
      expect(described_class.resource_display_name(resource)).to eq('project')
    end
  end
end
