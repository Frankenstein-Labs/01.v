# frozen_string_literal: true

module Gitlab
  module Llm
    class DuoChat
      include Gitlab::Utils::StrongMemoize

      SCOPELESS_CONTROLLERS = %w[search].freeze

      def self.duo_scope_hash(user, project, group, controller_name)
        if SCOPELESS_CONTROLLERS.include?(controller_name)
          { namespace: user.default_duo_namespace, default_namespace_applied: true }
        elsif project&.persisted?
          { project: project, default_namespace_applied: false }
        elsif group&.persisted?
          { namespace: group, default_namespace_applied: false }
        else # rubocop:disable Lint/DuplicateBranch -- readability
          { namespace: user.default_duo_namespace, default_namespace_applied: true }
        end
      end

      def initialize(user:, container: nil, project: nil, group: nil)
        @user = user

        container = nil unless container&.persisted?
        project = nil unless project&.persisted?
        group = nil unless group&.persisted?

        @container = container || project || group
        @project = project
        @group = group
      end

      def enabled_for_container?
        authorizer_response = if container
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
                              else
                                Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user)
                              end

        authorizer_response.allowed?
      end

      def agentic_mode_available?
        user.can?(:access_duo_agentic_chat, container)
      end

      def classic_chat_available?
        return false unless user

        user.can?(:access_duo_classic_chat, container)
      end

      def show_duo_entry_point?
        Gitlab::Llm::Chain::Utils::ChatAuthorizer.user(user: user).allowed?
      end

      def credits_available?
        return false unless user

        usage_quota_result.success?
      end

      def usage_billing_forbidden?
        return false unless user

        usage_quota_result.reason == :usage_billing_forbidden
      end

      def chat_disabled_reason
        return unless container

        authorizer_response = Gitlab::Llm::Chain::Utils::ChatAuthorizer.container(container: container, user: user)
        return if authorizer_response.allowed?

        container.is_a?(Group) ? :group : :project
      end

      def default_duo_namespace_check_passes?
        # User need to have default namespace setup so we can properly bill customer.
        # However, this is required only for SaaS. For Self-Managed instances we can skip this check.
        return true unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

        !!user.governing_namespace(container)
      end

      def user_model_selection_enabled?
        namespace_to_use = user.governing_namespace(container&.root_ancestor)

        return false unless namespace_to_use

        result = ::Ai::FeatureSettingSelectionService
                   .new(
                     user,
                     ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name,
                     namespace_to_use
                   ).execute

        result.success? && result.payload.present? && result.payload.user_model_selection_available?
      end

      private

      attr_reader :user, :container, :project, :group

      def usage_quota_result
        ::Ai::UsageQuotaService
          .new(user: user, namespace: group || project&.group)
          .execute
      end
      strong_memoize_attr :usage_quota_result
    end
  end
end
