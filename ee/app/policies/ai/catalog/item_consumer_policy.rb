# frozen_string_literal: true

module Ai
  module Catalog
    class ItemConsumerPolicy < ::BasePolicy
      delegate { @subject.project }
      delegate { @subject.group }

      condition(:custom_flow, scope: :subject) do
        @subject.item.custom_flow?
      end

      condition(:custom_agent, scope: :subject) do
        @subject.item.custom_agent?
      end

      condition(:third_party_flow, scope: :subject) do
        @subject.item.third_party_flow?
      end

      condition(:custom_flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.container, :ai_catalog_flows)
      end

      condition(:third_party_flows_available, scope: :subject) do
        ::Gitlab::Llm::StageCheck.available?(@subject.container, :ai_catalog_third_party_flows)
      end

      condition(:foundational_flow, scope: :subject) do
        @subject.item.foundational_flow?
      end

      condition(:foundational_flows_available, scope: :subject) do
        @subject.container.foundational_flows_available?
      end

      condition(:foundational_flow_in_allowlist, scope: :subject) do
        container = @subject.container
        container.enabled_flow_catalog_item_ids.include?(@subject.item.id)
      end

      condition(:beta_foundational_flow, scope: :subject) do
        @subject.item.foundational_flow? &&
          ::Ai::Catalog::FoundationalFlow.beta?(@subject.item.foundational_flow_reference)
      end

      condition(:beta_features_enabled, scope: :subject) do
        if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          root_ancestor = @subject.project&.root_ancestor || @subject.group&.root_ancestor
          root_ancestor&.experiment_features_enabled || false
        else
          ::Gitlab::CurrentSettings.instance_level_ai_beta_features_enabled?
        end
      end

      condition(:duo_external_agents_enabled, scope: :subject) do
        @subject.root_ancestor.duo_external_agents_enabled
      end

      condition(:duo_custom_flows_enabled, scope: :subject) do
        @subject.root_ancestor.duo_custom_flows_enabled
      end

      condition(:duo_custom_agents_enabled, scope: :subject) do
        @subject.root_ancestor.duo_custom_agents_enabled
      end

      condition(:pinned_version_available, scope: :subject) do
        @subject.pinned_version.present?
      end

      condition(:item_blocked_by_namespace_restriction, scope: :subject) do
        @subject.item.blocked_by_namespace_restriction?(@subject.root_ancestor)
      end

      condition(:internal_visibility_enabled, scope: :user) do
        ::Feature.enabled?(:ai_catalog_internal_visibility, @user)
      end

      condition(:outside_restricted_hierarchy, scope: :subject) do
        @subject.item.outside_restricted_hierarchy?(@subject.container)
      end

      condition(:pinned_version_draft, scope: :subject) do
        @subject.pinned_version.present? && @subject.pinned_version.draft?
      end

      condition(:foundational_flow_feature_flag_disabled, scope: :subject) do
        flow = @subject.item.foundational_flow
        flow && flow.blocked_by_feature_flag?(
          @subject.project&.root_ancestor || @subject.group&.root_ancestor
        )
      end

      condition(:ultimate_only_item, scope: :subject) do
        item = @subject.item
        if item.foundational_flow?
          ::Ai::Catalog::FoundationalFlow.ultimate_only?(item.foundational_flow_reference)
        elsif item.foundational_chat_agent?
          agent = ::Ai::FoundationalChatAgent.for_catalog_item(item.id)
          !!agent&.ultimate_only
        else
          false
        end
      end

      condition(:ultimate_license_available, scope: :subject) do
        root = @subject.project&.root_ancestor || @subject.group&.root_ancestor
        root&.licensed_feature_available?(:ai_features)
      end

      rule do
        ~pinned_version_available |
          pinned_version_draft |
          (foundational_flow & (~foundational_flows_available | ~foundational_flow_in_allowlist)) |
          (third_party_flow & ~third_party_flows_available)
      end.prevent :execute_ai_catalog_item

      rule do
        (beta_foundational_flow & ~beta_features_enabled) |
          (custom_flow & (~custom_flows_available | ~duo_custom_flows_enabled)) |
          (third_party_flow & ~duo_external_agents_enabled) |
          (ultimate_only_item & ~ultimate_license_available) |
          (custom_agent & ~duo_custom_agents_enabled) |
          item_blocked_by_namespace_restriction |
          foundational_flow_feature_flag_disabled
      end.prevent :execute_ai_catalog_item, :read_ai_catalog_item_consumer, :admin_ai_catalog_item_consumer

      rule { internal_visibility_enabled & outside_restricted_hierarchy }.policy do
        prevent :execute_ai_catalog_item
        prevent :read_ai_catalog_item_consumer
        prevent :admin_ai_catalog_item_consumer
      end
    end
  end
end
