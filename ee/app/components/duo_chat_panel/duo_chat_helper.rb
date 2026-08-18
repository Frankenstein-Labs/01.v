# frozen_string_literal: true

module DuoChatPanel
  module DuoChatHelper
    private

    def saas?
      ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
    end

    def duo_scope
      @duo_scope ||= ::Gitlab::Llm::DuoChat.duo_scope_hash(user, project, group, controller_name)
    end

    def subscription_expired?(group, project)
      saas? ? saas_subscription_expired?(group, project) : self_managed_subscription_expired?
    end

    def saas_subscription_expired?(group, project)
      namespace = (group || project)&.root_ancestor
      return false unless namespace&.gitlab_subscription

      namespace.gitlab_subscription.paid_and_expired?
    end

    def self_managed_subscription_expired?
      license = License.current
      license.present? && !license.trial? && license.expired?
    end

    def container
      duo_scope[:project] || duo_scope[:namespace]
    end
  end
end
