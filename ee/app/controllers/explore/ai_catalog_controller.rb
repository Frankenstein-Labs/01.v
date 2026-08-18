# frozen_string_literal: true

module Explore
  class AiCatalogController < Explore::ApplicationController
    feature_category :workflow_catalog
    before_action :authenticate_user!, unless: :public_explore_enabled?
    before_action :authorize_read_ai_catalog!
    before_action :set_instance_beta_features_enabled
    before_action do
      push_frontend_feature_flag(:ai_catalog_third_party_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_create_third_party_flows, current_user)
      push_frontend_feature_flag(:ai_catalog_mcp_servers, current_user)
      push_frontend_feature_flag(:ai_catalog_synthetic_foundational_items, current_user)
      push_frontend_feature_flag(:ai_catalog_bulk_item_consumer_create, current_user)
      push_frontend_feature_flag(:duo_agentic_chat_prefer_mcp_tools, current_user)
      push_frontend_feature_flag(:ai_catalog_internal_visibility, current_user)
      push_frontend_feature_flag(:merge_request_merged_flow_trigger, current_user)
      push_frontend_ability(ability: :read_ai_catalog_mcp_server, resource: ::Current.organization, user: current_user)
      push_frontend_ability(ability: :create_ai_catalog_mcp_server, resource: ::Current.organization,
        user: current_user)
      push_frontend_ability(ability: :update_ai_catalog_mcp_server, resource: ::Current.organization,
        user: current_user)
      push_frontend_ability(ability: :read_ai_catalog, user: current_user)
      push_frontend_ability(ability: :report_ai_catalog_item, user: current_user)
      push_frontend_ability(ability: :force_hard_delete_ai_catalog_item, user: current_user)
    end

    private

    def authorize_read_ai_catalog!
      if public_explore_enabled?
        render_404 unless ::Ai::Catalog.feature_available?
      else
        render_404 unless can?(current_user, :read_ai_catalog)
      end
    end

    def set_instance_beta_features_enabled
      @instance_beta_features_enabled = current_user.present? &&
        ::Ai::Catalog.user_can_access_experimental_and_beta_features?(current_user)
    end

    def public_explore_enabled?
      Feature.enabled?(:ai_catalog_public_explore, :instance)
    end
  end
end
