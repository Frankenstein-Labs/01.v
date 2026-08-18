# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::AiUsage::AiUsageEventTypeEnum, feature_category: :value_stream_management do
  it 'includes a value for each usage event type' do
    expect(described_class.values).to match(
      'CODE_SUGGESTIONS_REQUESTED' => have_attributes(value: 'code_suggestions_requested'),
      'CODE_SUGGESTION_ACCEPTED_IN_IDE' => have_attributes(value: 'code_suggestion_accepted_in_ide'),
      'CODE_SUGGESTION_REJECTED_IN_IDE' => have_attributes(value: 'code_suggestion_rejected_in_ide'),
      'CODE_SUGGESTION_DIRECT_ACCESS_TOKEN_REFRESH' => have_attributes(
        value: 'code_suggestion_direct_access_token_refresh'
      ),
      'CODE_SUGGESTION_SHOWN_IN_IDE' => have_attributes(value: 'code_suggestion_shown_in_ide'),
      'REQUEST_DUO_CHAT_RESPONSE' => have_attributes(value: 'request_duo_chat_response'),
      'TROUBLESHOOT_JOB' => have_attributes(value: 'troubleshoot_job'),
      'ENCOUNTER_DUO_CODE_REVIEW_ERROR_DURING_REVIEW' => have_attributes(
        value: 'encounter_duo_code_review_error_during_review'
      ),
      'FIND_NO_ISSUES_DUO_CODE_REVIEW_AFTER_REVIEW' => have_attributes(
        value: 'find_no_issues_duo_code_review_after_review'),
      'FIND_NOTHING_TO_REVIEW_DUO_CODE_REVIEW_ON_MR' => have_attributes(
        value: 'find_nothing_to_review_duo_code_review_on_mr'
      ),
      'POST_COMMENT_DUO_CODE_REVIEW_ON_DIFF' => have_attributes(
        value: 'post_comment_duo_code_review_on_diff'
      ),
      'REACT_THUMBS_UP_ON_DUO_CODE_REVIEW_COMMENT' => have_attributes(
        value: 'react_thumbs_up_on_duo_code_review_comment'
      ),
      'REACT_THUMBS_DOWN_ON_DUO_CODE_REVIEW_COMMENT' => have_attributes(
        value: 'react_thumbs_down_on_duo_code_review_comment'
      ),
      'REQUEST_REVIEW_DUO_CODE_REVIEW_ON_MR_BY_AUTHOR' => have_attributes(
        value: 'request_review_duo_code_review_on_mr_by_author'
      ),
      'REQUEST_REVIEW_DUO_CODE_REVIEW_ON_MR_BY_NON_AUTHOR' => have_attributes(
        value: 'request_review_duo_code_review_on_mr_by_non_author'
      ),
      'EXCLUDED_FILES_FROM_DUO_CODE_REVIEW' => have_attributes(
        value: 'excluded_files_from_duo_code_review'
      ),
      'PUBLISH_DUO_CODE_REVIEW_COMMENTS' => have_attributes(
        value: 'publish_duo_code_review_comments'
      ),
      'START_MCP_TOOL_CALL' => have_attributes(value: 'start_mcp_tool_call'),
      'FINISH_MCP_TOOL_CALL' => have_attributes(value: 'finish_mcp_tool_call'),
      'AGENT_PLATFORM_SESSION_CREATED' => have_attributes(value: 'agent_platform_session_created'),
      'AGENT_PLATFORM_SESSION_STARTED' => have_attributes(value: 'agent_platform_session_started'),
      'AGENT_PLATFORM_SESSION_FINISHED' => have_attributes(value: 'agent_platform_session_finished'),
      'AGENT_PLATFORM_SESSION_DROPPED' => have_attributes(value: 'agent_platform_session_dropped'),
      'AGENT_PLATFORM_SESSION_STOPPED' => have_attributes(value: 'agent_platform_session_stopped'),
      'AGENT_PLATFORM_SESSION_RESUMED' => have_attributes(value: 'agent_platform_session_resumed'),
      'DUO_WORKFLOW_WORKLOAD_COMPLETED' => have_attributes(value: 'duo_workflow_workload_completed'),
      'FIX_PIPELINE_SUGGESTION_APPLIED' => have_attributes(value: 'fix_pipeline_suggestion_applied'),
      'FIX_PIPELINE_SUGGESTION_POSTED' => have_attributes(value: 'fix_pipeline_suggestion_posted'),
      'VIEW_DUO_AGENTIC_SUBSCRIPTION_EXPIRED_EMPTY_STATE' => have_attributes(
        value: 'view_duo_agentic_subscription_expired_empty_state'
      ),
      'CLICK_DUO_AGENTIC_SUBSCRIPTION_EXPIRED_UPGRADE' => have_attributes(
        value: 'click_duo_agentic_subscription_expired_upgrade'
      ),
      'CLICK_DUO_AGENTIC_SUBSCRIPTION_EXPIRED_LEARN_MORE' => have_attributes(
        value: 'click_duo_agentic_subscription_expired_learn_more'
      ),
      'RESTORE_AI_CATALOG_ITEM' => have_attributes(value: 'restore_ai_catalog_item'),
      'SUMMARIZE_REVIEW' => have_attributes(value: 'summarize_review'),
      'SUMMARIZE_NEW_MERGE_REQUEST' => have_attributes(value: 'summarize_new_merge_request'),
      'GENERATE_MERGE_COMMIT_MESSAGE' => have_attributes(value: 'generate_merge_commit_message'),
      'AI_DUO_MESSAGING_FEEDBACK_SUBMITTED' => have_attributes(value: 'ai_duo_messaging_feedback_submitted'),
      'REQUEST_DUO_VULNERABILITY_RESOLUTION' => have_attributes(value: 'request_duo_vulnerability_resolution'),
      'EXPLAIN_VULNERABILITY' => have_attributes(value: 'explain_vulnerability'),
      'RESOLVE_FEATURE_DISCOVERY_SEARCH' => have_attributes(value: 'resolve_feature_discovery_search')
    )
  end
end
