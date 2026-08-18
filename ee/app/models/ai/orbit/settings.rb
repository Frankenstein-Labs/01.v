# frozen_string_literal: true

# Single entry point for all Orbit enablement gates.
#
# Encapsulates:
#   * platform-availability feature flags (`knowledge_graph`, `orbit_foundational_agent`)
#   * the per-user opt-in feature flag (`orbit_user_preference`)
#   * the user preference killswitch + four granular subsettings
#
# Callers should never reach into these flags or the user preference
# directly: go through this module so that any future change to the
# gating logic only has to be made in one place.
#
# Reference pattern: Search::Zoekt (ee/app/models/search/zoekt.rb).
module Ai
  module Orbit
    module Settings
      SUBSETTINGS = {
        agent: 'orbit_agent_enabled',
        chat: 'orbit_agentic_chat_enabled',
        foundational: 'orbit_other_foundational_agents_enabled',
        custom_agents: 'orbit_custom_agents_enabled'
      }.freeze

      class << self
        # Standalone Orbit agent (e.g. workflow_definition: 'orbit_agent/v1').
        def agent_enabled?(user)
          subsetting_enabled?(user, :agent)
        end

        # Orbit tools available in agentic chat (workflow_definition: 'chat').
        def chat_enabled?(user)
          subsetting_enabled?(user, :chat)
        end

        # Orbit tools for non-chat foundational agents
        # (e.g. 'security_analyst_agent/v1', 'software_development').
        def foundational_enabled?(user)
          subsetting_enabled?(user, :foundational)
        end

        # Orbit tools for user-built custom agents (Ai::Catalog item versions
        # that have selected Orbit MCP tools).
        def custom_agents_enabled?(user)
          subsetting_enabled?(user, :custom_agents)
        end

        # Whether the per-user preference UI / params should be exposed.
        def user_preference_flag_enabled?(user)
          ::Feature.enabled?(:orbit_user_preference, user)
        end

        # Whether the per-user Orbit preferences section should render. Gates on
        # Orbit availability (namespace enrollment on SaaS, :orbit license on
        # self-managed), not orbit_user_preference, which only governs the
        # subsetting behaviour in #subsetting_enabled?.
        def user_preference_section_visible?(user)
          return false unless user
          return false unless platform_available?(user)

          if ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
            participating_namespace?(user)
          else
            ::Analytics::KnowledgeGraph::OrbitLicense.available_for?(user)
          end
        end

        # Reads the saved killswitch value from the user preference. Unlike
        # the gate predicates (`agent_enabled?` etc.), this does NOT take
        # platform-availability flags into account: it is the answer to
        # "did the user opt in?" rather than "is Orbit on right now?".
        # Intended for UI state (e.g. greying out subsettings).
        def killswitch_on?(user)
          return false unless user

          user.user_preference.orbit_enabled
        end

        private

        # Both platform gates must hold for any Orbit functionality: Knowledge
        # Graph availability (config + FF, via the module) and the foundational-agent flag.
        def platform_available?(user)
          ::Analytics::KnowledgeGraph.enabled_for?(user) &&
            ::Feature.enabled?(:orbit_foundational_agent, user)
        end

        # Paid root namespace enrolled in the Knowledge Graph. SaaS-only;
        # the finder returns nothing off GitLab.com.
        def participating_namespace?(user)
          ::Analytics::KnowledgeGraph::GoverningNamespaceFinder.new(user).candidates.exists?
        end

        def subsetting_enabled?(user, subsetting)
          return false unless user
          return false unless platform_available?(user)

          # When the per-user preference flag is off, fall back to the
          # legacy behaviour: every workflow gets Orbit tools (the original
          # pre-!234196 baseline, modulo platform availability).
          return true unless user_preference_flag_enabled?(user)

          preference = user.user_preference

          # GitLab team members get the standalone Orbit agent on by default
          # until they save their /preferences form. Scoped to `:agent`
          # because we are not rolling the standalone agent to customers yet
          # (it is also gated by `orbit_foundational_agent`), but we still
          # want team members to use it without an opt-in step. Once the
          # user saves the form (`enabled` key present), their saved value
          # is honoured by the normal path below.
          return true if subsetting == :agent &&
            user.gitlab_team_member? &&
            !preference.orbit_settings.key?('enabled')

          # Killswitch: when off, no subsetting is enabled.
          return false unless preference.orbit_enabled

          preference.orbit_settings.fetch(SUBSETTINGS.fetch(subsetting), true)
        end
      end
    end
  end
end
