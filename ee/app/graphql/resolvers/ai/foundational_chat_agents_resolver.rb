# frozen_string_literal: true

module Resolvers
  module Ai
    class FoundationalChatAgentsResolver < BaseResolver
      description 'AI foundational chat agents.'

      type ::Types::Ai::FoundationalChatAgentType.connection_type, null: true

      # Foundational chat agents are loaded from an in-memory fixed-items model
      # rather than the database, so the per-item cost is negligible compared to
      # a DB-backed paginated list. Use a reduced multiplier (half the default 0.01)
      def self.complexity_multiplier(_args)
        0.005
      end

      argument :project_id, ::Types::GlobalIDType[Project],
        required: false,
        description: 'Global ID of the project where the chat is present.'

      argument :namespace_id, ::Types::GlobalIDType[::Namespace],
        required: false,
        description: 'Global ID of the namespace where the chat is present.'

      def resolve(*, project_id: nil, namespace_id: nil)
        enabled_agents = if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
                           enabled_foundational_agents_in_namespace(
                             resolve_namespace(current_user, namespace_id, project_id),
                             current_user
                           )
                         else
                           enabled_foundational_agents_in_organization(
                             ::Organizations::Organization.default_organization
                           )
                         end

        enabled_agents
          .reject do |agent|
            next false unless agent.reference == 'orbit_agent'
            # For anonymous callers we don't filter here: upstream
            # namespace/license filters handle access control.
            next false unless current_user

            !::Ai::Orbit::Settings.agent_enabled?(current_user)
          end
          .sort_by(&:id)
      end

      private

      def resolve_namespace(current_user, namespace_id, project_id)
        return unless current_user

        current_root_namespace = find_object(project_id || namespace_id)&.root_ancestor
        current_user.governing_namespace(current_root_namespace)
      end

      def enabled_foundational_agents_in_namespace(namespace, current_user)
        unless namespace && Ability.allowed?(current_user, :read_namespace, namespace)
          return ::Ai::FoundationalChatAgent.only_duo_chat_agent
        end

        agents = namespace.enabled_foundational_agents

        return agents if namespace.licensed_feature_available?(:ai_features)

        agents.reject(&:ultimate_only)
      end

      def enabled_foundational_agents_in_organization(organization)
        agents = organization.enabled_foundational_agents

        return agents if ::License.feature_available?(:ai_features)
        return agents.reject(&:ultimate_only) if ::GitlabSubscriptions::Duo.active_self_managed_gitlab_credits?

        agents
      end

      def find_object(id)
        return unless id

        ::Gitlab::Graphql::Lazy.force(GitlabSchema.object_from_id(id))
      end
    end
  end
end
