# frozen_string_literal: true

module Types
  module Ai
    module ModelSelection
      # rubocop: disable Graphql/AuthorizeTypes -- authorization handled by parent field on FeatureSettingType / FeatureSettingBase
      # NOTE: This intentionally does NOT inherit from OfferedModelType. Granular token
      # authorization resolves the type-level directive via each field's `owner`, and graphql-ruby
      # keeps a field's `owner` pointing at the class where it was declared. Inherited fields would
      # therefore keep OfferedModelType (which has no granular directive) as their owner and be
      # denied for granular tokens. Declaring the fields locally keeps them owned by this type and
      # covered by the directive below, and avoids silently re-introducing that gap whenever a new
      # field is added to OfferedModelType.
      class AllowListModelType < ::Types::BaseObject
        graphql_name 'AiModelSelectionAllowListModel'
        description 'GitLab-managed model row in the model selection allowlist for a feature'

        # Shared by the namespace and instance/admin surfaces. Each row carries
        # the group (`:group` boundary) on the namespace surface; on the
        # instance surface `group` is nil so resolution falls through to
        # `:instance`.
        authorize_granular_token permissions: :read_model_selection_allowlist,
          boundaries: [
            { boundary: :group, boundary_type: :group },
            { boundary: :instance, boundary_type: :instance }
          ]

        # Model attributes mirrored from OfferedModelType; declared locally (see the note above).
        field :ref, GraphQL::Types::String, null: false, description: 'Identifier for the offered model.'

        field :name, GraphQL::Types::String, null: false,
          description: 'Humanized name for the offered model, e.g "Chat GPT 4o".'

        field :model_provider, GraphQL::Types::String, null: true,
          experiment: { milestone: '18.6' },
          description: 'Provider for the model, e.g "OpenAI".'

        field :model_description, GraphQL::Types::String, null: true, # rubocop:disable GraphQL/ExtractType -- this is an offered model attribute, no need for new type
          experiment: { milestone: '18.7' },
          description: 'Brief description of the model, e.g "Fast, cost-effective responses".'

        field :cost_indicator, GraphQL::Types::String, null: true,
          experiment: { milestone: '18.7' },
          description: 'Presentational cost indicator for model usage, e.g "$", "$$", "$$$".'

        field :allowed, GraphQL::Types::Boolean, null: false,
          description: 'Whether the model is allowed for this feature under the effective allowlist. ' \
            'The currently chosen/default model for the feature is implicitly allowed and is therefore ' \
            'true even when the allowlist is enabled and the model is not in the stored allowlist refs.'

        field :currently_chosen_model_for_feature, GraphQL::Types::Boolean, null: false,
          description: 'Whether this model is the currently chosen/default model for the feature. ' \
            'This is the admin-chosen model when set, otherwise the GitLab default model from definitions.'
      end
      # rubocop: enable Graphql/AuthorizeTypes
    end
  end
end
