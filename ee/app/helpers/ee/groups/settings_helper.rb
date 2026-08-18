# frozen_string_literal: true

module EE
  module Groups
    module SettingsHelper
      def unique_project_download_limit_settings_data
        settings = @group.namespace_settings || ::NamespaceSetting.new
        limit = settings.unique_project_download_limit
        interval = settings.unique_project_download_limit_interval_in_seconds
        allowlist = settings.unique_project_download_limit_allowlist
        alertlist = settings.unique_project_download_limit_alertlist
        auto_ban_users = settings.auto_ban_user_on_excessive_projects_download

        {
          group_full_path: @group.full_path,
          max_number_of_repository_downloads: limit,
          max_number_of_repository_downloads_within_time_period: interval,
          git_rate_limit_users_allowlist: allowlist,
          git_rate_limit_users_alertlist: alertlist,
          auto_ban_user_on_excessive_projects_download: auto_ban_users.to_s
        }
      end

      def show_group_ai_settings_general?
        GitlabSubscriptions::Duo.duo_settings_available?(@group.root_ancestor)
      end

      def show_group_ai_settings_page?
        @group.licensed_ai_features_available? && show_gitlab_duo_settings_app?(@group)
      end

      def show_virtual_registries_setting?(group)
        ::VirtualRegistries.any_registry_available_for_settings?(group, current_user)
      end

      def group_ai_general_settings_helper_data
        {
          on_general_settings_page: 'true',
          redirect_path: edit_group_path(@group)
        }.merge(group_ai_settings_helper_data)
      end

      def group_ai_configuration_settings_helper_data
        {
          on_general_settings_page: 'false',
          redirect_path: group_settings_gitlab_duo_path(@group)
        }.merge(group_ai_settings_helper_data)
      end

      def group_ai_settings_helper_data
        duo_cascading_settings_data.merge(duo_feature_settings_data)
      end

      def group_amazon_q_settings_view_model_data
        {
          group_id: @group.id.to_s,
          init_availability: @group.namespace_settings.duo_availability.to_s,
          init_auto_review_enabled: @group.amazon_q_integration&.auto_review_enabled.present?,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?,
          duo_availability_admin_locked: @group.namespace_settings.admin_locked_duo_features_enabled?,
          duo_availability_cascading_settings: cascading_namespace_settings_tooltip_raw_data(:duo_features_enabled, @group, method(:edit_group_path))
        }
      end

      def group_amazon_q_settings_view_model_json
        ::Gitlab::Json.generate(group_amazon_q_settings_view_model_data.deep_transform_keys { |k| k.to_s.camelize(:lower) })
      end

      def seat_control_disabled_help_text
        _("Restricted access and user cap cannot be turned on. The group or one of its subgroups or projects is shared externally.")
      end

      def usage_billing_dashboard_data(group, plans_data)
        premium_plan = find_plan(plans_data, ::Plan::PREMIUM)

        {
          user_usage_path: group_settings_gitlab_credits_dashboard_user_path(group, '__USERNAME__'),
          namespace_path: group.full_path,
          upgrade_button_path: plan_purchase_url(group, premium_plan),
          is_saas: 'true',
          is_free: free_namespace?(group).to_s,
          is_paid_base_plan: group.paid?.to_s,
          purchase_credits_path: subscription_portal_gitlab_com_purchase_credits_url(group.id),
          credits_generalization_ui: ::Feature.enabled?(:credits_generalization_ui, group).to_s
        }
      end

      def seat_control_warning?(group)
        ::Feature.enabled?(:bso_minimal_access_fallback, group) && !!group.saml_provider&.enabled?
      end

      def seat_control_saml_scim_warning
        saml_link = link_to('', help_page_path('user/group/saml_sso/_index.md'))
        scim_link = link_to('', help_page_path('user/group/saml_sso/scim_setup.md'))

        message = safe_format(
          _(
            '%{saml_link_start}SAML%{saml_link_end}/%{scim_link_start}SCIM%{scim_link_end} provisioning is active. ' \
              'With restricted access turned on and if no seats are available, new users provisioned through SAML/SCIM are ' \
              'assigned the non-billable Minimal Access role.'
          ),
          tag_pair(saml_link, :saml_link_start, :saml_link_end),
          tag_pair(scim_link, :scim_link_start, :scim_link_end)
        )

        tag.div(class: 'gl-mt-3') do
          concat(sprite_icon('warning', size: 16, css_class: 'gl-mr-2 gl-text-orange-500'))
          concat(message)
        end
      end

      private

      def free_namespace?(group)
        group.plan_name_for_upgrading == ::Plan::FREE && !group.has_active_add_on_purchase?(:gitlab_credits)
      end

      def duo_cascading_settings_data
        {
          duo_availability_cascading_settings: cascading_tooltip_data(:duo_features_enabled),
          duo_remote_flows_cascading_settings: cascading_tooltip_data(:duo_remote_flows_enabled),
          duo_foundational_flows_cascading_settings: cascading_tooltip_data(:duo_foundational_flows_enabled),
          duo_custom_agents_cascading_settings: cascading_tooltip_data(:duo_custom_agents_enabled),
          duo_custom_flows_cascading_settings: cascading_tooltip_data(:duo_custom_flows_enabled),
          duo_external_agents_cascading_settings: cascading_tooltip_data(:duo_external_agents_enabled),
          tool_approval_for_session_cascading_settings: cascading_tooltip_data(:tool_approval_for_session_enabled),
          ai_audit_events_storage_cascading_settings: cascading_tooltip_data(:ai_audit_events_storage_enabled)
        }
      end

      def duo_feature_settings_data
        {
          duo_availability: @group.namespace_settings.duo_availability.to_s,
          are_duo_settings_locked: @group.namespace_settings.duo_features_enabled_locked?.to_s,
          duo_availability_admin_locked: @group.namespace_settings.admin_locked_duo_features_enabled?.to_s,
          experiment_features_enabled: @group.namespace_settings.experiment_features_enabled.to_s,
          duo_core_features_enabled: @group.namespace_settings.duo_core_features_enabled.to_s,
          prompt_cache_enabled: @group.namespace_settings.model_prompt_cache_enabled.to_s,
          are_experiment_settings_allowed: (@group.experiment_settings_allowed? && gitlab_com_subscription?).to_s,
          are_prompt_cache_settings_allowed: (@group.prompt_cache_settings_allowed? && gitlab_com_subscription?).to_s,
          update_id: @group.id,
          root_namespace_id: @group.root_ancestor.id,
          is_saas: saas?.to_s,
          group_full_path: @group.full_path
        }.merge(
          duo_workflow_settings_data,
          ai_access_level_settings_data,
          foundational_flows_settings_data,
          foundational_agents_data,
          namespace_access_rules_data
        )
      end

      def duo_workflow_settings_data
        {
          duo_agent_platform_enabled: @group.duo_agent_platform_enabled.to_s,
          duo_workflow_available: (@group.root? && current_user.can?(:admin_duo_workflow, @group)).to_s,
          duo_workflow_mcp_available: (@group.root? && current_user.can?(:admin_duo_workflow, @group) && @group.licensed_feature_available?(:ai_catalog)).to_s,
          duo_workflow_mcp_enabled: @group.duo_workflow_mcp_enabled.to_s,
          ai_usage_data_collection_available: (@group.root? && gitlab_com_subscription?).to_s,
          ai_usage_data_collection_enabled: @group.ai_usage_data_collection_enabled.to_s,
          ai_catalog_restricted_to_group_hierarchy: @group.ai_catalog_restricted_to_group_hierarchy.to_s,
          ai_catalog_restricted_to_group_hierarchy_available: @group.root?.to_s,
          ai_audit_events_storage_enabled: @group.namespace_settings.ai_audit_events_storage_enabled.to_s,
          prompt_injection_protection_level: @group.prompt_injection_protection_level.to_s,
          prompt_injection_protection_available: (::Feature.enabled?(:ai_prompt_scanning, current_user) && current_user.can?(:admin_duo_workflow, @group)).to_s,
          show_duo_agent_platform_enablement_setting: show_duo_agent_platform_enablement_setting?.to_s,
          include_recommended_allowed: @group.ai_settings.include_recommended_allowed.to_s,
          allow_all_unix_sockets: @group.ai_settings.allow_all_unix_sockets.to_s,
          allow_project_extension: @group.ai_settings.allow_project_extension.to_s,
          enforce_on_local_clients: @group.ai_settings.enforce_on_local_clients.to_s
        }
      end

      def ai_access_level_settings_data
        {
          ai_minimum_access_level_to_execute: @group.ai_minimum_access_level_execute_with_fallback,
          ai_minimum_access_level_to_execute_async: @group.ai_minimum_access_level_execute_async_with_fallback,
          ai_settings_minimum_access_level_manage: @group.ai_minimum_access_level_manage,
          ai_settings_minimum_access_level_enable_on_projects: @group.ai_minimum_access_level_enable_on_projects
        }
      end

      def foundational_agents_data
        statuses = @group.foundational_agents_statuses
        statuses = reject_unavailable_orbit_agent(statuses)

        unless @group.licensed_feature_available?(:ai_features)
          ultimate_only_references = ::Ai::FoundationalChatAgent.all
            .select(&:ultimate_only)
            .map(&:reference)
          statuses = statuses.reject { |s| ultimate_only_references.include?(s[:reference]) }
        end

        {
          foundational_agents_default_enabled: @group.foundational_agents_default_enabled.to_s,
          foundational_agents_statuses: ::Gitlab::Json.generate(statuses),
          show_foundational_agents_availability: show_foundational_agents_availability?.to_s,
          show_foundational_agents_per_agent_availability: show_foundational_agents_per_agent_availability?.to_s
        }
      end

      def foundational_flows_settings_data
        {
          duo_enterprise_active: @group.root_ancestor.has_active_add_on_purchase?([:duo_enterprise]).to_s,
          code_review_flow_consent_given: @group.root_ancestor.consented_to?(:code_review_flow_dap_routing).to_s,
          duo_remote_flows_availability: @group.namespace_settings.duo_remote_flows_availability.to_s,
          duo_foundational_flows_availability: @group.namespace_settings.duo_foundational_flows_availability.to_s,
          duo_custom_agents_availability: @group.namespace_settings.duo_custom_agents_availability.to_s,
          duo_custom_flows_availability: @group.namespace_settings.duo_custom_flows_availability.to_s,
          duo_external_agents_availability: @group.namespace_settings.duo_external_agents_availability.to_s,
          tool_approval_for_session_availability: @group.namespace_settings.tool_approval_for_session_availability.to_s,
          available_foundational_flows: available_foundational_flows_json,
          selected_foundational_flow_references: selected_foundational_flows_json,
          duo_template_project: duo_template_project_json,
          show_duo_template_project: show_duo_template_project_json
        }
      end

      def available_foundational_flows_json
        return ::Gitlab::Json.generate([]) unless @group.root?

        flows = ::Ai::Catalog::FoundationalFlow.available_for_group(@group)

        ::Gitlab::Json.generate(
          flows.map do |item|
            {
              name: item.translated_display_name,
              description: item.translated_description,
              descriptionHtml: markdown(item.translated_description, project: nil),
              reference: item.foundational_flow_reference
            }
          end
        )
      end

      def selected_foundational_flows_json
        return [].to_json unless @group.root?

        @group.selected_foundational_flow_references.to_json
      end

      def duo_template_project_json
        return unless @group.root?

        project = @group.namespace_template_setting&.duo_template_project
        return unless project

        {
          id: project.id,
          name: project.name,
          name_with_namespace: project.name_with_namespace,
          full_path: project.full_path,
          avatar_url: project.avatar_url
        }.to_json
      end

      def show_duo_template_project_json
        (@group.root? && @group.root_ancestor.id.present?).to_json
      end

      def cascading_tooltip_data(setting_key)
        cascading_namespace_settings_tooltip_data(setting_key, @group, method(:edit_group_path))[:tooltip_data]
      end

      def namespace_access_rules_data
        {
          namespace_access_rules: ::Gitlab::Json.dump(namespace_access_rules),
          new_group_path: new_group_path(parent_id: @group.id, anchor: 'create-group-pane')
        }
      end

      def namespace_access_rules
        rules = ::Ai::NamespaceFeatureAccessRule.by_root_namespace_group_by_through_namespace(@group)

        Ai::FeatureAccessRuleTransformer.transform(rules)
      end

      # Mirrors the Orbit availability gate in Admin::AiConfigurationPresenter.
      def reject_unavailable_orbit_agent(statuses)
        return statuses if ::Analytics::KnowledgeGraph.enabled_for?(current_user)

        statuses.reject { |s| s[:reference] == 'orbit_agent' }
      end

      def show_foundational_agents_availability?
        saas? && @group.root?
      end

      def show_duo_agent_platform_enablement_setting?
        saas? && @group.root?
      end

      def show_foundational_agents_per_agent_availability?
        saas? && @group.root?
      end

      def saas?
        ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end
    end
  end
end
