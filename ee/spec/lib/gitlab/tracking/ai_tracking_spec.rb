# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house, :clean_gitlab_redis_shared_state do
    let_it_be(:group) { create(:group, path: 'group') }
    let_it_be(:organization) { create(:organization) }
    let_it_be(:current_user) { create(:user, organizations: [organization]) }
    let(:event_context) do
      { user: current_user }
    end

    let_it_be(:project) { create(:project, namespace: group, path: 'project') }

    subject(:track_event) { described_class.track_event(event_name, **event_context) }

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    context 'for unknown event' do
      let(:event_name) { 'something_unrelated' }

      it { is_expected.to be_nil }
    end

    describe 'guessing namespace ID' do
      let(:event_name) { 'request_duo_chat_response' }
      let(:expected_event_hash) do
        { user: current_user, event: event_name, extras: {} }
      end

      context 'with project ID provided' do
        let(:event_context) { super().merge(project_id: project.id, namespace_id: nil) }

        let(:expected_event_hash) do
          super().merge(namespace_id: project.project_namespace_id)
        end

        it 'includes project namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with project object is provided' do
        let(:event_context) { super().merge(project: project, namespace_id: nil) }

        let(:expected_event_hash) do
          super().merge(namespace_id: project.project_namespace_id)
        end

        it 'includes project namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with namespace ID provided' do
        let(:event_context) { super().merge(namespace_id: group.id) }

        let(:expected_event_hash) do
          super().merge(namespace_id: group.id)
        end

        it 'includes namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with namespace object is provided' do
        let(:event_context) { super().merge(namespace: group, namespace_id: nil) }

        let(:expected_event_hash) do
          super().merge(namespace_id: group.id)
        end

        it 'includes namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end

      context 'with namespace ID and project ID is provided' do
        let(:event_context) { super().merge(namespace_id: group.id, project_id: project.id) }

        let(:expected_event_hash) do
          super().merge(namespace_id: project.project_namespace_id)
        end

        it 'takes project namespace id' do
          expect(Ai::UsageEvent).to receive(:new).with(expected_event_hash).and_call_original
          track_event
        end
      end
    end

    describe 'deprecated events' do
      events = %w[code_suggestions_requested code_suggestion_direct_access_token_refresh]

      events.each do |e|
        it "declares `#{e} as deprecated" do
          expect(described_class.deprecated_event?(e)).to be_truthy
        end
      end
    end

    %w[code_suggestion_shown_in_ide code_suggestion_accepted_in_ide code_suggestion_rejected_in_ide].each do |e|
      context "for `#{e}` event" do
        let(:event_name) { e }
        let(:event_context) { super().merge(extras) }
        let(:extras) do
          {
            unique_tracking_id: "AB1",
            suggestion_size: 10,
            language: 'cobol',
            branch_name: 'main',
            ide_name: 'VSCode',
            ide_vendor: 'Microsoft',
            ide_version: '2',
            extension_name: 'cobol-vscode',
            extension_version: '1',
            language_server_version: '3.11',
            model_name: 'ModelName',
            model_engine: 'ModelEngine'
          }
        end

        let(:expected_pg_attributes) do
          {
            user_id: current_user.id,
            event: event_name,
            extras: extras
          }
        end

        let(:expected_ch_attributes) do
          {
            user_id: current_user.id,
            event: Ai::UsageEvent.events[event_name],
            extras: extras.to_json
          }
        end

        it_behaves_like 'standard ai usage event tracking'
      end
    end

    context 'for `request_duo_chat_response` event' do
      let(:event_name) { 'request_duo_chat_response' }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          extras: {}
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          extras: {}.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for `troubleshoot_job` event' do
      let(:event_name) { 'troubleshoot_job' }
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:pipeline) { create(:ci_pipeline, project: project, merge_request: merge_request) }
      let(:job) { create(:ci_build, pipeline: pipeline, project: project, user_id: current_user.id) }

      let(:event_context) { super().merge({ job: job }) }

      let(:extras) do
        {
          job_id: job.id,
          project_id: project.id,
          pipeline_id: pipeline.id,
          merge_request_id: merge_request.id
        }
      end

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: project.project_namespace_id,
          extras: extras
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
          extras: extras.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    %w[
      agent_platform_session_created
      agent_platform_session_started
      agent_platform_session_finished
      agent_platform_session_dropped
      agent_platform_session_stopped
      agent_platform_session_resumed
    ].each do |e|
      context "for `#{e}` event" do
        let(:event_name) { e }
        let(:event_context) do
          super().merge({ project: project, value: 1, label: "software_development", property: "ide" })
        end

        let(:expected_pg_attributes) do
          {
            user_id: current_user.id,
            event: event_name,
            namespace_id: project.project_namespace_id,
            extras: {
              project_id: project.id,
              environment: "ide",
              flow_type: "software_development",
              session_id: 1
            }
          }
        end

        let(:expected_ch_attributes) do
          {
            user_id: current_user.id,
            event: Ai::UsageEvent.events[event_name],
            namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
            extras: {
              project_id: project.id,
              session_id: 1,
              flow_type: "software_development",
              environment: "ide"
            }.to_json
          }
        end

        it_behaves_like 'standard ai usage event tracking'
      end
    end

    %w[
      encounter_duo_code_review_error_during_review
      find_no_issues_duo_code_review_after_review
      find_nothing_to_review_duo_code_review_on_mr
      post_comment_duo_code_review_on_diff
      react_thumbs_up_on_duo_code_review_comment
      react_thumbs_down_on_duo_code_review_comment
      request_review_duo_code_review_on_mr_by_author
      request_review_duo_code_review_on_mr_by_non_author
      excluded_files_from_duo_code_review
      publish_duo_code_review_comments
    ].each do |e|
      context "for `#{e}` event" do
        let(:event_name) { e }
        let(:event_context) { super().merge({ project: project }) }

        let(:expected_pg_attributes) do
          {
            user_id: current_user.id,
            event: event_name,
            namespace_id: project.project_namespace_id,
            extras: {}
          }
        end

        let(:expected_ch_attributes) do
          {
            user_id: current_user.id,
            event: Ai::UsageEvent.events[event_name],
            namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
            extras: {}.to_json
          }
        end

        it_behaves_like 'standard ai usage event tracking'
      end
    end

    context 'for `restore_ai_catalog_item` event' do
      let(:event_name) { 'restore_ai_catalog_item' }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          extras: {}
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          extras: {}.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for `summarize_review` event' do
      let(:event_name) { 'summarize_review' }
      let(:event_context) { super().merge(project: project) }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: project.project_namespace_id,
          extras: {}
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
          extras: {}.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for `summarize_new_merge_request` event' do
      let(:event_name) { 'summarize_new_merge_request' }
      let(:event_context) { super().merge(project: project) }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: project.project_namespace_id,
          extras: {}
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
          extras: {}.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for `ai_duo_messaging_feedback_submitted` event' do
      let(:event_name) { 'ai_duo_messaging_feedback_submitted' }
      let(:event_context) do
        super().merge(
          namespace: group,
          label: 'thumbs_down',
          value: 42,
          property: 'slack',
          reason: 'incorrect',
          comment: 'wrong project'
        )
      end

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: group.id,
          extras: {
            feedback: 'thumbs_down',
            workflow_id: 42,
            surface: 'slack'
          }
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: group.reload.traversal_path(with_organization: false),
          extras: {
            feedback: 'thumbs_down',
            workflow_id: 42,
            surface: 'slack'
          }.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for `generate_merge_commit_message` event' do
      let(:event_name) { 'generate_merge_commit_message' }
      let(:event_context) { super().merge(project: project) }

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: project.project_namespace_id,
          extras: {}
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
          extras: {}.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    %w[
      request_duo_vulnerability_resolution
      explain_vulnerability
    ].each do |duo_feature_event|
      context "for `#{duo_feature_event}` event" do
        let(:event_name) { duo_feature_event }
        let(:event_context) { super().merge(project: project) }

        let(:expected_pg_attributes) do
          {
            user_id: current_user.id,
            event: event_name,
            namespace_id: project.project_namespace_id,
            extras: {}
          }
        end

        let(:expected_ch_attributes) do
          {
            user_id: current_user.id,
            event: Ai::UsageEvent.events[event_name],
            namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
            extras: {}.to_json
          }
        end

        it_behaves_like 'standard ai usage event tracking'
      end
    end

    context 'for `resolve_feature_discovery_search` event' do
      let(:event_name) { 'resolve_feature_discovery_search' }
      let(:event_context) do
        super().merge(
          namespace: group,
          label: 'exact_map',
          value: 250
        )
      end

      let(:expected_extras) do
        {
          resolution_tier: 'exact_map',
          latency_ms: 250
        }
      end

      let(:expected_pg_attributes) do
        {
          user_id: current_user.id,
          event: event_name,
          namespace_id: group.id,
          extras: expected_extras
        }
      end

      let(:expected_ch_attributes) do
        {
          user_id: current_user.id,
          event: Ai::UsageEvent.events[event_name],
          namespace_path: group.reload.traversal_path(with_organization: false),
          extras: expected_extras.to_json
        }
      end

      it_behaves_like 'standard ai usage event tracking'
    end

    context 'for MCP events' do
      let(:mcp_extras) do
        {
          session_id: 123,
          tool_name: "test_tool",
          has_tool_call_success: true,
          failure_reason: nil,
          error_status: nil
        }
      end

      %w[
        start_mcp_tool_call
        finish_mcp_tool_call
      ].each do |e|
        context "for `#{e}` event" do
          let(:event_name) { e }
          let(:event_context) do
            super().merge({
              project: project,
              session_id: 123,
              tool_name: "test_tool",
              has_tool_call_success: true,
              failure_reason: nil,
              error_status: nil
            })
          end

          let(:expected_pg_attributes) do
            {
              user_id: current_user.id,
              event: event_name,
              namespace_id: project.project_namespace_id,
              extras: mcp_extras
            }
          end

          let(:expected_ch_attributes) do
            {
              user_id: current_user.id,
              event: Ai::UsageEvent.events[event_name],
              namespace_path: project.project_namespace.reload.traversal_path(with_organization: false),
              extras: mcp_extras.to_json
            }
          end

          it_behaves_like 'standard ai usage event tracking'
        end
      end
    end
  end

  describe '.track_user_activity' do
    let(:current_user) { create(:user) }

    it 'refreshes user metrics for last activity' do
      expect(Ai::UserMetrics).to receive(:refresh_last_activity_on).with(current_user).and_call_original

      described_class.track_user_activity(current_user)
    end
  end

  describe 'code_suggestions feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:code_suggestions).keys).to match_array(%w[
        code_suggestions_requested
        code_suggestion_shown_in_ide
        code_suggestion_accepted_in_ide
        code_suggestion_rejected_in_ide
        code_suggestion_direct_access_token_refresh
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'agent_platform feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:agent_platform).keys).to match_array(%w[
        agent_platform_session_created
        agent_platform_session_started
        agent_platform_session_finished
        agent_platform_session_dropped
        agent_platform_session_stopped
        agent_platform_session_resumed
        view_duo_agentic_subscription_expired_empty_state
        click_duo_agentic_subscription_expired_upgrade
        click_duo_agentic_subscription_expired_learn_more
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'ai_catalog feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:ai_catalog).keys).to match_array(%w[
        restore_ai_catalog_item
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'code_review feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:code_review).keys).to match_array(%w[
        encounter_duo_code_review_error_during_review
        find_no_issues_duo_code_review_after_review
        find_nothing_to_review_duo_code_review_on_mr
        post_comment_duo_code_review_on_diff
        react_thumbs_up_on_duo_code_review_comment
        react_thumbs_down_on_duo_code_review_comment
        request_review_duo_code_review_on_mr_by_author
        request_review_duo_code_review_on_mr_by_non_author
        excluded_files_from_duo_code_review
        publish_duo_code_review_comments
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'chat feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:chat).keys).to match_array(%w[
        request_duo_chat_response
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'troubleshoot_job feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:troubleshoot_job).keys).to match_array(%w[
        troubleshoot_job
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'mcp feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:mcp).keys).to match_array(%w[
        start_mcp_tool_call
        finish_mcp_tool_call
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'fix_pipeline feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:fix_pipeline).keys).to match_array(%w[
        fix_pipeline_suggestion_posted
        fix_pipeline_suggestion_applied
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'duo_workflow feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:duo_workflow).keys).to match_array(%w[
        duo_workflow_workload_completed
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'summarize_review feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:summarize_review).keys).to match_array(%w[
        summarize_review
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'summarize_new_merge_request feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:summarize_new_merge_request).keys).to match_array(%w[
        summarize_new_merge_request
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'generate_merge_commit_message feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:generate_merge_commit_message).keys).to match_array(%w[
        generate_merge_commit_message
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'request_duo_vulnerability_resolution feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:request_duo_vulnerability_resolution).keys).to match_array(%w[
        request_duo_vulnerability_resolution
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'explain_vulnerability feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:explain_vulnerability).keys).to match_array(%w[
        explain_vulnerability
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end

  describe 'feature_discovery feature events' do
    it 'contains exact events' do
      expect(described_class.registered_events(:feature_discovery).keys).to match_array(%w[
        resolve_feature_discovery_search
      ]), "When adding events, consider how they should be added to corresponding materialized views."
    end
  end
end
