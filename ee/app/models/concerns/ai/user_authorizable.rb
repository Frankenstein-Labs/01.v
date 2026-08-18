# frozen_string_literal: true

module Ai
  module UserAuthorizable
    extend ActiveSupport::Concern

    GROUP_WITH_AI_ENABLED_CACHE_PERIOD = 1.hour
    GROUP_WITH_AI_ENABLED_CACHE_KEY = 'group_with_ai_enabled'

    DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_PERIOD = 5.minutes
    DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_KEY = 'duo_feature_enabled_through_namespace'

    GROUP_WITH_MCP_SERVER_ENABLED_CACHE_PERIOD = 1.hour
    GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY = 'group_with_mcp_server_enabled'

    ROOT_GROUP_IDS_CACHE_KEY = 'root_group_ids'
    ROOT_GROUP_IDS_CACHE_PERIOD = 10.minutes

    DUO_PRO_ADD_ON_CACHE_KEY = 'user-%{user_id}-code-suggestions-add-on-cache'
    # refers to add-ons listed in GitlabSubscriptions::AddOn::DUO_ADD_ONS
    DUO_ADD_ONS_CACHE_KEY = 'user-%{user_id}-duo-add-ons-cache'
    AMAZON_Q_FEATURES = [
      :code_suggestions,
      :chat,
      :duo_chat, # alternate name of (classic, non-agentic) :chat
      :explain_vulnerability,
      :generate_commit_message,
      :glab_ask_git_command,
      :resolve_vulnerability,
      :review_merge_request,
      :summarize_comments,
      :troubleshoot_job,
      :generate_description,
      :summarize_review,
      :summarize_new_merge_request
    ].freeze

    DAP_ACCESS_GROUP = :duo_agent_platform
    DAP_ENFORCED_UNIT_PRIMITIVES = %w[duo_agent_platform duo_chat].freeze

    UNPAID_ENABLEMENT_TYPES = %w[duo_core tier].freeze

    THROUGH_NAMESPACE_ACCESS_FEATURE_MAP = {
      explain_vulnerability: :duo_classic,
      resolve_vulnerability: :duo_classic,
      summarize_review: :duo_classic,
      measure_comment_temperature: :duo_classic,
      generate_description: :duo_classic,
      generate_commit_message: :duo_classic,
      chat: :duo_classic,
      duo_chat: :duo_classic,
      summarize_new_merge_request: :duo_classic,
      categorize_question: :duo_classic,
      review_merge_request: :duo_classic,
      glab_ask_git_command: :duo_classic,
      code_suggestions: :duo_classic,
      troubleshoot_job: :duo_classic,
      ask_build: :duo_classic,
      ask_issue: :duo_classic,
      ask_epic: :duo_classic,
      ask_merge_request: :duo_classic,
      ask_commit: :duo_classic,
      summarize_comments: :duo_classic,
      duo_workflow: :duo_agent_platform,
      duo_agent_platform: :duo_agent_platform,
      agentic_chat: :duo_agent_platform,
      ai_catalog: :duo_agent_platform,
      ai_catalog_flows: :duo_agent_platform
    }.freeze

    Response = Struct.new(
      :allowed?,
      :namespace_ids,
      :namespace_ids_from_all_addons,
      :enablement_type,
      :authorized_by_duo_core,
      keyword_init: true
    ) do
      def initialize(**kwargs)
        kwargs[:namespace_ids_from_all_addons] ||= kwargs[:namespace_ids]
        super
      end

      def unpaid?
        UNPAID_ENABLEMENT_TYPES.include?(enablement_type)
      end
    end

    included do
      def duo_available_namespace_ids
        cache_key = duo_addons_cache_key_formatted

        Rails.cache.fetch(cache_key, expires_in: 1.hour) do
          GitlabSubscriptions::UserAddOnAssignment.by_user(self).for_active_gitlab_duo_purchase
            .pluck('subscription_add_on_purchases.namespace_id') # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's purchases
            .uniq
        end
      end

      # Returns namespace IDs where user has Duo Core
      # access through namespace-level settings.
      # We currently provide an alternative pathway to Duo Core features beyond add-on purchase
      # assignments, enabling organizations
      # to grant Duo Core access at the namespace level
      # without requiring individual user purchases.
      def duo_core_ids_via_namespace_settings
        groups = groups_with_duo_core_enabled
        groups.present? ? groups.ids : []
      end

      def duo_addons_cache_key_formatted
        format(DUO_ADD_ONS_CACHE_KEY, user_id: id)
      end

      def duo_pro_cache_key_formatted
        self.class.duo_pro_cache_key_formatted(id)
      end

      def eligible_for_self_managed_gitlab_duo_pro?
        return false if gitlab_com_subscription?

        active? && !bot? && !ghost?
      end

      # rubocop: disable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups
      def gitlab_com_root_group_ids
        return unless gitlab_com_subscription?

        Rails.cache.fetch(
          ['users', id, ROOT_GROUP_IDS_CACHE_KEY],
          expires_in: ROOT_GROUP_IDS_CACHE_PERIOD
        ) do
          banned_root_group_ids = ::Namespaces::NamespaceBan.where(user_id: id).pluck(:namespace_id)

          authorized_root_ancestor_ids - banned_root_group_ids
        end
      end
      # rubocop: enable Database/AvoidUsingPluckWithoutLimit -- limited to a single user's groups

      def any_group_with_ai_available?
        Rails.cache.fetch(
          ['users', id, GROUP_WITH_AI_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_AI_ENABLED_CACHE_PERIOD
        ) do
          member_namespaces.namespace_settings_with_ai_features_enabled.with_ai_supported_plan.any?
        end
      end

      def code_suggestions_blocked_for?(scope)
        return false unless saas?

        # The root namespace is the flag actor, so a whole group flips together.
        namespace = governing_namespace(scope)
        # Without a namespace we cannot attribute the request to an owner who
        # turned Duo off, so allow it.
        return false unless namespace
        return false unless Feature.enabled?(:block_code_suggestions_when_duo_disabled, namespace)

        # Read the scope, not the namespace, so a project can override an unlocked
        # parent. Only an explicit false blocks: nil means the namespace never set
        # it and cascades to the instance setting, which is on for GitLab.com.
        (scope || namespace).duo_features_enabled == false
      end

      def any_group_with_mcp_server_enabled?
        Rails.cache.fetch(
          ['users', id, GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY],
          expires_in: GROUP_WITH_MCP_SERVER_ENABLED_CACHE_PERIOD
        ) do
          Group.by_id(gitlab_com_root_group_ids).with_mcp_server_enabled.any?
        end
      end

      def default_duo_namespace
        user_preference.duo_default_namespace_with_fallback
      end

      def governing_namespace(scope = nil)
        root_namespace = scope&.root_ancestor || root_namespace_from_application_context

        if root_namespace && !root_namespace.user_namespace? && root_namespace.member_of_self_or_descendant?(self)
          return root_namespace
        end

        default_duo_namespace
      end

      def root_namespace_from_application_context
        group_path = Gitlab::ApplicationContext.current_context_attribute(:group)
        project_path = Gitlab::ApplicationContext.current_context_attribute(:project)

        if group_path
          ::Group.find_by_full_path(group_path)&.root_ancestor
        elsif project_path
          ::Project.find_by_full_path(project_path)&.root_ancestor
        end
      end

      alias_method :billable_duo_namespace, :governing_namespace

      def foundational_agent_available?(reference, scope = nil)
        return false unless can?(:access_duo_agentic_chat, scope || :global)

        duo_foundational_agents_container(scope)&.foundational_agent_enabled?(reference) || false
      end

      def duo_foundational_agents_container(scope = nil)
        unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          # rubocop:disable Gitlab/AvoidDefaultOrganization -- on self-managed, foundational agent settings are org-level, not per-namespace
          return ::Organizations::Organization.default_organization
          # rubocop:enable Gitlab/AvoidDefaultOrganization
        end

        governing_namespace(scope)
      end

      def allowed_to_use?(
        ai_feature,
        unit_primitive_name: nil,
        licensed_feature: :ai_features,
        root_namespace: nil
      )
        allowed_to_use(
          ai_feature,
          unit_primitive_name: unit_primitive_name,
          licensed_feature: licensed_feature,
          root_namespace: root_namespace
        ).allowed?
      end

      def dap_identity_verification_required?(container)
        strong_memoize_with(:dap_identity_verification_required, container) do
          next false unless can?(:access_duo_features, container)

          identity_verification_required?(DAP_ACCESS_GROUP, container.root_ancestor)
        end
      end

      def allowed_to_use_for_resource?(*args, resource:, **kwargs)
        auth_response = allowed_to_use(*args, **kwargs)

        return false unless auth_response.allowed?
        return true unless saas? # We only check for namespaces in SaaS

        (resource.respond_to?(:root_ancestor) &&
          auth_response.namespace_ids_from_all_addons.include?(resource.root_ancestor.id)) ||
          user_preference.duo_default_namespace_with_fallback.present?
      end

      def allowed_by_namespace_ids(...)
        allowed_to_use(...).namespace_ids
      end

      def allowed_to_use(ai_feature, root_namespace: nil, **options)
        auth_user = authorization_user
        return auth_user.allowed_to_use(ai_feature, root_namespace: root_namespace, **options) if auth_user != self

        response = duo_entitlement(ai_feature, root_namespace: root_namespace, **options)

        apply_identity_verification_gate(response, ai_feature, root_namespace)
      end

      def duo_entitlement(
        ai_feature,
        unit_primitive_name: nil,
        licensed_feature: :ai_features,
        feature_setting: nil,
        root_namespace: nil
      )
        auth_user = authorization_user
        if auth_user != self
          # Service accounts cannot hold add-on subscriptions; all checks below must run against the linked human user.
          return auth_user.duo_entitlement(
            ai_feature,
            unit_primitive_name: unit_primitive_name,
            licensed_feature: licensed_feature,
            feature_setting: feature_setting,
            root_namespace: root_namespace
          )
        end

        amazon_q_response = check_amazon_q_feature(ai_feature)
        return amazon_q_response if amazon_q_response

        through_namespace_response = check_access_through_namespace(ai_feature, root_namespace)
        return through_namespace_response if through_namespace_response&.allowed? == false

        # Check if feature and unit primitive are valid and available
        feature_data = Gitlab::Llm::Utils::AiFeaturesCatalogue.search_by_name(ai_feature)
        return denied_response unless feature_data

        # NOTE: Callers must pass unit_primitive_name explicitly for features where the ai_feature
        # name differs from the unit primitive name (e.g. agentic chat requires unit_primitive_name: :duo_chat).
        # Without it, feature_for_unit_primitive won't resolve the correct feature setting.
        feature_setting ||= get_self_hosted_feature_setting(unit_primitive_name || ai_feature)

        # Access through DAP Self-hosted
        self_hosted_dap_response = check_dap_self_hosted_feature(feature_setting)
        return self_hosted_dap_response if self_hosted_dap_response

        unit_primitive = get_unit_primitive_model(
          unit_primitive_name || ai_feature,
          feature_setting: feature_setting
        )
        return denied_response unless unit_primitive

        authorize_unit_primitive(unit_primitive, ai_feature, feature_data, licensed_feature)
      end

      def allowed_to_use_through_namespace?(ai_feature, root_namespace = nil)
        # This looks duplicated, but more logic will come in this function with
        # https://gitlab.com/gitlab-org/gitlab/-/work_items/584384
        check = check_access_through_namespace(ai_feature, root_namespace)

        # treats nil as true since this means no rule was setup, or that this check
        # shouldn't be taken into account
        check.nil? || check.allowed?
      end

      def check_access_through_namespace(ai_feature, root_namespace = nil)
        mapped_ai_feature = THROUGH_NAMESPACE_ACCESS_FEATURE_MAP[ai_feature]

        return unless mapped_ai_feature
        return check_access_through_namespace_in_saas(mapped_ai_feature, root_namespace) if saas?

        check_access_through_namespace_at_instance(mapped_ai_feature)
      end

      def duo_agent_platform_enabled_via_credits?
        if saas?
          gitlab_credits_purchases.any? do |purchase|
            namespace = purchase.namespace
            next unless namespace

            namespace.duo_agent_platform_enabled
          end
        else
          gitlab_credits_purchases.any? &&
            ::Ai::Setting.for_organization_read_only(organization).duo_agent_platform_enabled
        end
      end

      private

      def check_access_through_namespace_at_instance(mapped_ai_feature)
        return unless ::Ai::FeatureAccessRule.exists?

        has_access = Rails.cache.fetch(
          ['users', id, DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_KEY, mapped_ai_feature],
          expires_in: DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_PERIOD
        ) do
          ::Ai::FeatureAccessRule.accessible_for_user(self, mapped_ai_feature).exists?
        end

        Response.new(
          allowed?: has_access,
          namespace_ids: [],
          authorized_by_duo_core: false,
          enablement_type: 'dap_group_membership'
        )
      end

      def check_access_through_namespace_in_saas(mapped_ai_feature, root_namespace = nil)
        authority_namespace = governing_namespace(root_namespace)

        # We must have at least one authority namespace
        return unless authority_namespace

        # If the authority namespace has no rules, it is nil
        return unless namespace_has_access_rules?(authority_namespace)

        has_access = Rails.cache.fetch(
          ['users', id, DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_KEY, authority_namespace.id, mapped_ai_feature],
          expires_in: DUO_FEATURE_ENABLED_THROUGH_NAMESPACE_CACHE_PERIOD
        ) do
          ::Ai::NamespaceFeatureAccessRule
            .accessible_for_user(self, mapped_ai_feature, authority_namespace)
            .exists?
        end

        Response.new(
          allowed?: has_access,
          namespace_ids: [authority_namespace.id],
          authorized_by_duo_core: false,
          enablement_type: 'dap_group_membership'
        )
      end

      def namespace_has_access_rules?(authority_namespace)
        Gitlab::SafeRequestStore.fetch(namespace_has_access_rules_cache_key(authority_namespace.id)) do
          ::Ai::NamespaceFeatureAccessRule.for_namespace(authority_namespace).exists?
        end
      end

      def namespace_has_access_rules_cache_key(namespace_id)
        "users:#{id}:namespace_has_access_rules:#{namespace_id}"
      end

      def check_dap_self_hosted_feature(feature_setting)
        return unless feature_setting&.self_hosted?

        dap_features = %w[duo_agent_platform duo_agent_platform_agentic_chat]

        # Code Suggestion feature are considered DAP feature for online cloud licenses
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/593893#note_3214359210 for more details
        dap_features.concat(%w[code_generations code_completions]) if ::License.current&.online_cloud_license?

        return unless dap_features.include?(feature_setting.feature)

        enablement_type = 'self_hosted_usage_billing'

        if ::License.current&.offline_cloud_license?
          purchases = GitlabSubscriptions::AddOnPurchase.for_self_managed.for_self_hosted_dap.active
          enablement_type = 'self_hosted_dap'
          return denied_response unless purchases.exists?
        end

        Response.new(
          allowed?: true,
          namespace_ids: [],
          enablement_type: enablement_type,
          authorized_by_duo_core: false
        )
      end

      def get_unit_primitive_model(unit_primitive_name, feature_setting: nil)
        return Gitlab::CloudConnector::DataModel::UnitPrimitive.find_by_name(unit_primitive_name) if
          ::Gitlab::Saas.feature_available?(:cloud_connector_static_catalog)

        feature_setting ||= ::Ai::FeatureSetting.feature_for_unit_primitive(unit_primitive_name)

        unit_primitive_name = :self_hosted_models if feature_setting&.self_hosted?

        Gitlab::CloudConnector::DataModel::UnitPrimitive.find_by_name(unit_primitive_name)
      end

      def get_self_hosted_feature_setting(unit_primitive_name)
        # do not run this logic on gitlab.com as self-hosted models are available only
        # for self-managed instances
        return if ::Gitlab::Saas.feature_available?(:cloud_connector_static_catalog)

        ::Ai::FeatureSetting.feature_for_unit_primitive(unit_primitive_name)
      end

      def check_add_on_purchases(unit_primitive)
        add_ons = unit_primitive[:add_ons] || []

        # NOTE: We are passing `nil` as the resource to avoid filtering by namespace.
        # This is _not_ a good use of this API, and we should separate filtering by namespace
        # from filtering by user seat assignments. While this works, it will actually join
        # all add-on purchases in all tenant namespaces, which is not ideal.
        purchases = GitlabSubscriptions::AddOnPurchase.for_active_add_ons(add_ons, nil)

        self_hosted_dap_add_on = purchases.for_self_hosted_dap

        # For self-hosted DAP, all users get access without explicit assignment
        # For other add-ons, check if the user is explicitly assigned
        purchases = purchases.assigned_to_user(self) unless self_hosted_dap_add_on.any?

        return unless purchases.any?

        namespace_ids = purchases.uniq_namespace_ids

        namespace_ids_from_all_addons = namespace_ids
        duo_core_response = check_duo_core_features(unit_primitive)
        if duo_core_response&.allowed?
          namespace_ids_from_all_addons += duo_core_response.namespace_ids
          namespace_ids_from_all_addons.uniq!
        end

        Response.new(
          allowed?: true,
          namespace_ids: namespace_ids,
          namespace_ids_from_all_addons: namespace_ids_from_all_addons,
          enablement_type: purchases.last.normalized_add_on_name,
          authorized_by_duo_core: false
        )
      end

      def check_duo_core_features(unit_primitive)
        return unless active? && !bot?

        add_ons = unit_primitive[:add_ons] || []

        return unless add_ons.include?("duo_core") && duo_core_add_on?

        if saas?
          groups = groups_with_duo_core_enabled
          return unless groups.any?

          Response.new(
            allowed?: true,
            namespace_ids: groups.ids,
            enablement_type: duo_core_add_on_purchase.normalized_add_on_name,
            authorized_by_duo_core: true
          )
        elsif ::Ai::Setting.duo_core_features_enabled?(organization)
          Response.new(
            allowed?: true,
            namespace_ids: [],
            enablement_type: duo_core_add_on_purchase.normalized_add_on_name,
            authorized_by_duo_core: true
          )
        end
      end

      def check_gitlab_credits_access(unit_primitive, ai_feature)
        return unless active? && !bot?

        return unless unit_primitive[:add_ons]&.include?("gitlab_credits")

        purchases = gitlab_credits_purchases
        return unless purchases.any?

        if unit_primitive[:name].to_s.in?(DAP_ENFORCED_UNIT_PRIMITIVES)
          return denied_response if ai_feature == :chat

          return unless duo_agent_platform_enabled_via_credits?
        end

        Response.new(
          allowed?: true,
          namespace_ids: purchases.filter_map(&:namespace_id).uniq,
          enablement_type: purchases.last.normalized_add_on_name,
          authorized_by_duo_core: false
        )
      end

      def check_free_access(unit_primitive, feature_data, licensed_feature)
        return unless unit_primitive.free_access?

        if saas?
          check_saas_free_access(feature_data)
        else
          check_sm_free_access(licensed_feature)
        end
      end

      def check_saas_free_access(feature_data)
        seats = namespaces_allowed_in_com(feature_data[:maturity])

        if seats.any?
          Response.new(allowed?: true, namespace_ids: seats, enablement_type: 'tier', authorized_by_duo_core: false)
        else
          denied_response
        end
      end

      def check_sm_free_access(licensed_feature)
        Response.new(allowed?: licensed_to_use_in_sm?(licensed_feature), namespace_ids: [],
          authorized_by_duo_core: false)
      end

      def denied_response
        Response.new(allowed?: false, namespace_ids: [], authorized_by_duo_core: false)
      end

      def authorize_unit_primitive(unit_primitive, ai_feature, feature_data, licensed_feature)
        check_add_on_purchases(unit_primitive) ||
          check_duo_core_features(unit_primitive) ||
          check_gitlab_credits_access(unit_primitive, ai_feature) ||
          check_free_access(unit_primitive, feature_data, licensed_feature) ||
          denied_response
      end

      def apply_identity_verification_gate(response, ai_feature, root_namespace)
        return response unless identity_verification_required?(ai_feature, root_namespace, entitlement: response)

        denied_response
      end

      def identity_verification_required?(ai_feature, root_namespace, entitlement: nil)
        ::Users::IdentityVerification::AuthorizeDuo.new(
          user: self, ai_feature: ai_feature, root_namespace: root_namespace, entitlement: entitlement
        ).identity_verification_required?
      end

      def groups_with_duo_core_enabled
        Namespace.id_in(gitlab_com_root_group_ids)
          .namespace_settings_with_duo_core_features_enabled
      end

      def duo_core_add_on?
        duo_core_add_on_purchase.present?
      end

      def duo_core_add_on_purchase
        @duo_core_add_on_purchase ||= GitlabSubscriptions::AddOnPurchase.for_duo_core.for_user(self).active.first
      end

      def gitlab_credits_purchases
        @gitlab_credits_purchases ||= if saas?
                                        GitlabSubscriptions::AddOnPurchase
                                          .for_gitlab_credits.for_user(self).active
                                          .includes(namespace: :ai_settings).to_a
                                      else
                                        GitlabSubscriptions::AddOnPurchase
                                          .for_gitlab_credits.for_self_managed.active.to_a
                                      end
      end

      def check_amazon_q_feature(ai_feature)
        return unless ::Ai::AmazonQ.connected?
        return unless AMAZON_Q_FEATURES.include?(ai_feature)

        Response.new(
          allowed?: true,
          namespace_ids: [],
          enablement_type: 'duo_amazon_q',
          authorized_by_duo_core: false
        )
      end

      def namespaces_allowed_in_com(maturity)
        namespaces = member_namespaces.with_ai_supported_plan
        namespaces = namespaces.namespace_settings_with_ai_features_enabled if maturity != :ga
        namespaces.ids
      end

      def licensed_to_use_in_sm?(licensed_feature)
        License.feature_available?(licensed_feature)
      end

      def saas?
        Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
      end
    end

    class_methods do
      def clear_group_with_ai_available_cache(ids)
        cache_keys_ai_features = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_AI_ENABLED_CACHE_KEY] }
        cache_keys_billable_duo_pro_group_ids = Array.wrap(ids).map do |id|
          ["users", id, ROOT_GROUP_IDS_CACHE_KEY]
        end

        cache_keys = cache_keys_ai_features + cache_keys_billable_duo_pro_group_ids
        ::Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      def clear_group_with_mcp_server_enabled_cache(ids)
        cache_keys = Array.wrap(ids).map { |id| ["users", id, GROUP_WITH_MCP_SERVER_ENABLED_CACHE_KEY] }

        ::Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      def duo_pro_cache_key_formatted(user_id)
        format(DUO_PRO_ADD_ON_CACHE_KEY, user_id: user_id)
      end
    end
  end
end
