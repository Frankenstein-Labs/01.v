# frozen_string_literal: true

module Ai
  module Catalog
    class FoundationalFlow
      module Attributes
        extend ActiveSupport::Concern

        DEFAULT_FLOW_VERSION = '1.0.0'
        FEATURE_MATURITIES = %w[experimental beta ga].freeze
        ENVIRONMENTS = Ai::DuoWorkflows::Workflow.environments.keys.freeze
        CODING_ENVIRONMENTS = ::Ai::Catalog::CodingEnvironment::VALUES.keys.freeze

        included do
          auto_generate_ids!

          # Unique versioned identifier (e.g. "fix_pipeline/v1") used to look up the flow
          # and select its Flow Registry config in Duo Workflow Service.
          attribute :foundational_flow_reference, :string

          # User-facing name shown in the UI.
          attribute :display_name, :string

          # Name of the AI unit primitive/feature this flow is gated and tracked against.
          attribute :ai_feature, :string,
            default: "duo_agent_platform"

          # Privileges actually granted to a running workflow. Falls back to
          # pre_approved_agent_privileges when empty.
          attribute :agent_privileges,
            default: []

          # Privileges the flow may use without per-run user approval.
          attribute :pre_approved_agent_privileges,
            default: []

          # Whether the agent can pause execution to request human/user input.
          attribute :allow_agent_to_request_user, :boolean,
            default: false

          # Execution environment: "web", "ambient", or "cli".
          attribute :environment, :string,
            default: "ambient"

          # Maturity level ("experimental", "beta", "ga"); drives beta-only availability gating.
          attribute :feature_maturity, :string

          # Brief user-facing description of what the flow does.
          attribute :description, :string

          # Event types (e.g. mention, assign) that auto-create flow triggers for a consumer.
          attribute :triggers,
            default: []

          # A nil value means the flow has no event restrictions (any event is allowed). An empty array means the
          # flow explicitly supports no trigger events.
          attribute :supported_events

          # JSON-schema-like filter checked before a trigger fires (e.g. only run
          # fix_pipeline on failed pipelines).
          attribute :precondition,
            default: {}

          # Filename of the flow's icon, resolved against the GitLab SVGs assets.
          attribute :avatar, :string

          # Restricts availability to groups with an Ultimate license.
          attribute :ultimate_only, :boolean,
            default: false

          # Name of a GitLab feature flag that gates this flow at the group level.
          # nil means the flow is available to everyone who meets the other criteria.
          attribute :feature_flag, :string

          # Flows that manage their own discussion threads can opt out of the generic
          # progress note that is otherwise posted when the flow is triggered by an
          # @mention. Defaults to false so existing flows are unaffected.
          attribute :suppress_mention_progress_note, :boolean,
            default: false

          # Flows that post their own "session started" note (e.g. Code Review's
          # progress note) can opt out of the generic agent-session-started system
          # note that CreateWorkflowService otherwise posts on the noteable.
          # Defaults to false so existing flows are unaffected.
          attribute :suppress_agent_session_note, :boolean,
            default: false

          # Class implementing .resolve to build the workflow's goal string per trigger event type.
          attribute :goal_templates

          # Lambda resolving the GitLab resource (e.g. a merge request) a workflow
          # session should be linked to. Called with keyword arguments `project:`
          # (a `Project`) and `goal:` (a `String`, or `nil`).
          # Returns the `Noteable` object to where system notes will be added.
          attribute :noteable_resolver

          # Lambda resolving the CI pipeline a workflow session should be linked to
          # as its source (link_type: :source). Called with keyword arguments
          # `project:` (a `Project`) and `goal:` (a `String`, or `nil`).
          # Returns the `Ci::Pipeline` the flow was initiated against, or `nil`.
          attribute :source_pipeline_resolver

          # Lambda resolving the additional context a workflow sends to AIGW.
          # Called with keyword arguments `resource:` (any GitLab resource, e.g. a `MergeRequest`).
          # Returns a `Hash[category => content]` to be sent to AIGW.
          attribute :additional_context_resolver

          # What kind of coding environment the flow needs when its workload starts.
          # See `Ai::Catalog::CodingEnvironment` for the accepted values and for how this
          # is resolved against a catalog flow's own `flow_config` declaration.
          attribute :coding_environment, :string,
            default: 'full'

          # Flow Registry config version used to start the workflow.
          attribute :flow_version, :string,
            default: DEFAULT_FLOW_VERSION

          # Lambda resolving a runtime override of the flow's reference and version
          # (e.g. to route to an experimental Flow Registry config behind a feature
          # flag). Called with keyword arguments `container:` (a `Namespace` or
          # `Project`) and `user:` (a `User`, or `nil`).
          # Returns a `[foundational_flow_reference, flow_version]` Array, or `nil`
          # to use the flow's own `foundational_flow_reference` and `flow_version`.
          attribute :flow_version_resolver

          validates :display_name,
            :foundational_flow_reference,
            :ai_feature,
            :description,
            presence: true

          validates :coding_environment,
            inclusion: { in: CODING_ENVIRONMENTS }

          validates :environment,
            inclusion: { in: ENVIRONMENTS }

          validates :feature_maturity,
            presence: true,
            inclusion: { in: FEATURE_MATURITIES }

          validates :noteable_resolver, 'ai/catalog/resolver': { keywords: [:project, :goal] }
          validates :source_pipeline_resolver, 'ai/catalog/resolver': { keywords: [:project, :goal] }
          validates :additional_context_resolver, 'ai/catalog/resolver': { keywords: [:resource] }
          validates :flow_version_resolver, 'ai/catalog/resolver': { keywords: [:container, :user] }
        end
      end
    end
  end
end
