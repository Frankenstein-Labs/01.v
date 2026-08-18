# frozen_string_literal: true

module EE
  module Gitlab
    module GonHelper
      extend ::Gitlab::Utils::Override

      override :add_gon_variables
      def add_gon_variables
        super

        gon.roadmap_epics_limit = 1000

        if current_user && defined?(Llm)
          ai_chat = {
            total_model_token: ::Llm::ExplainCodeService::TOTAL_MODEL_TOKEN_LIMIT,
            max_response_token: ::Llm::ExplainCodeService::MAX_RESPONSE_TOKENS,
            input_content_limit: ::Llm::ExplainCodeService::INPUT_CONTENT_LIMIT
          }

          push_to_gon_attributes('ai', 'chat', ai_chat)
        end

        push_frontend_feature_flags

        # Used by Self-Managed customers
        gon.subscriptions_url = ::Gitlab::Routing.url_helpers.subscription_portal_url

        return unless ::Gitlab.com?

        gon.subscriptions_legacy_sign_in_url = ::Gitlab::Routing.url_helpers.subscription_portal_legacy_sign_in_url
        gon.billing_accounts_url             = ::Gitlab::Routing.url_helpers.subscription_portal_billing_accounts_url
        gon.is_gitlab_team_member            = current_user.present? && ::Gitlab::Com.gitlab_com_group_member?(current_user)
      end

      def push_frontend_feature_flags
        push_frontend_feature_flag(:advanced_context_resolver, current_user)

        push_frontend_feature_flag(:duo_ui_next, current_user)
        push_frontend_feature_flag(:duo_chat_binary_feedback, current_user)
        push_frontend_feature_flag(:duo_chat_workplan_empty_state, current_user)
        push_frontend_feature_flag(:duo_workplan_async_flow, current_user)
        push_frontend_feature_flag(:agentic_manual_retry_for_duo_chat_responses, current_user)
        push_frontend_feature_flag(:duo_chat_clarification_question_tool, current_user)
        push_frontend_feature_flag(:agentic_chat_flow_registry_migration, current_user)
        push_frontend_feature_flag(:no_duo_classic_for_duo_core_users, current_user)
        push_frontend_feature_flag(:duo_panel_history_stack_persistence, current_user)
        push_frontend_feature_flag(:dap_web_search, current_user)

        # Only advertise Orbit flags where the service is configured, else the
        # toggle surfaces and its actions 404 against the gated backends.
        return unless ::Analytics::KnowledgeGraph.service_configured?

        push_frontend_feature_flag(:orbit_user_preference, current_user, type: :beta)
        push_frontend_feature_flag(:knowledge_graph, current_user)
        push_frontend_feature_flag(:orbit_foundational_agent, current_user)
      end

      # Exposes if a licensed feature is available.
      #
      # name - The name of the licensed feature
      # obj  - the object to check the licensed feature on (project, namespace)
      def push_licensed_feature(name, obj = nil)
        enabled = if obj
                    obj.feature_available?(name)
                  else
                    ::License.feature_available?(name)
                  end

        push_to_gon_attributes(:licensed_features, name, enabled)
      end

      # Exposes if a SaaS feature is available.
      #
      # name - The name of the SaaS feature
      def push_saas_feature(name)
        push_to_gon_attributes(:saas_features, name, ::Gitlab::Saas.feature_available?(name))
      end

      def push_dedicated_feature(name)
        push_to_gon_attributes(:dedicated_features, name, ::Gitlab::Dedicated.feature_available?(name))
      end
    end
  end
end
