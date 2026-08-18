# frozen_string_literal: true

module DuoChatPanel
  class Component < ViewComponent::Base
    include DuoChatPanel::DuoChatHelper
    include DuoChatPanel::StartTrial
    include ::Gitlab::Utils::StrongMemoize

    def initialize(user:, project:, group:, controller_name: nil)
      @user = user
      @project = project
      @group = group
      @controller_name = controller_name
    end

    def render?
      return false unless user

      component_instance.present?
    end

    private

    attr_reader :user, :project, :group, :controller_name

    def component_instance
      return unless user

      @component_instance ||=
        # show_chat? returns true if the user has Duo access anywhere, but we need to show
        # the non-admin empty state when Duo is disabled on this specific container even if the user has
        # Duo access somewhere else. Therefore, show_duo_disabled_non_admin? needs to be checked first.
        if show_duo_disabled_non_admin?
          DuoDisabledNonAdminComponent.new(container: duo_container, user: user)
        elsif show_identity_verification?
          IdentityVerificationComponent.new(container: duo_container, user: user)
        elsif show_chat? || show_subscription_expired?
          ChatComponent.new(user: user, project: project, group: group, controller_name: controller_name)
        elsif show_trial_expired?
          TrialExpiredComponent.new(container: duo_container, user: user)
        elsif can_start_trial?(user, source: duo_container.source)
          StartTrialComponent.new(container: duo_container, user: user)
        elsif access_denied?
          AccessDeniedComponent.new(container: duo_container, user: user)
        end
    end

    def show_chat?
      ::Gitlab::Llm::DuoChat.new(user: user).show_duo_entry_point?
    end

    def show_trial_expired?
      if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        namespace = (project || group)&.root_ancestor
        return false unless namespace

        GitlabSubscriptions::Trials.free_plan_expired?(namespace)
      else
        GitlabSubscriptions::Trials.self_managed_non_dedicated_expired_ultimate_trial?(License.current)
      end
    end

    def show_subscription_expired?
      subscription_expired?(group, project)
    end

    def access_denied?
      !::Gitlab::CurrentSettings.duo_never_on?
    end

    def show_identity_verification?
      return false unless duo_container.source&.persisted?
      return false unless duo_container.source.duo_features_enabled

      user.dap_identity_verification_required?(duo_container.source)
    end

    def show_duo_disabled_non_admin?
      !!duo_container.persisted? && dap_disabled? && can_not_enable_duo?
    end

    def dap_disabled?
      !duo_container.duo_features_enabled
    end

    def can_not_enable_duo?
      !duo_container.user_can_admin?(user)
    end

    def duo_container
      DuoChatPanel::Container.new(
        project: project, group: group, user: user, controller_name: controller_name
      )
    end
    strong_memoize_attr :duo_container
  end
end
