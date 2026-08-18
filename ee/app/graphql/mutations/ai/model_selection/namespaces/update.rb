# frozen_string_literal: true

module Mutations
  module Ai
    module ModelSelection
      module Namespaces
        class Update < BaseMutation
          graphql_name 'AiModelSelectionNamespaceUpdate'
          description "Updates or creates settings for AI features for a namespace."
          authorize :admin_group_model_selection

          field :ai_feature_settings,
            [::Types::Ai::ModelSelection::Namespaces::FeatureSettingType],
            null: false,
            description: 'List of AI feature settings after mutation.',
            experiment: { milestone: '18.1' }

          argument :group_id, ::Types::GlobalIDType[::Group],
            required: true,
            description: 'Group for the model selection.'

          argument :features, [::Types::Ai::ModelSelection::FeaturesEnum],
            required: true,
            description: 'Array of AI features being configured (for single or batch update).'

          argument :offered_model_ref, GraphQL::Types::String,
            required: true,
            description: 'Identifier of the selected model for the feature.'

          def resolve(**args)
            @group_id = args[:group_id]

            group = authorized_find!(id: group_id)

            return { ai_feature_settings: [], errors: ['At least one feature is required'] } if args[:features].empty?

            upsert_args = args.except(:features, :group_id)

            results = args[:features].map do |feature|
              upsert_feature_setting(group, upsert_args.merge(feature: feature))
            end

            errors = results.select(&:error?).flat_map(&:errors)
            feature_settings = results.reject(&:error?).flat_map(&:payload)

            decorated_feature_settings = ::Gitlab::Graphql::Representation::ModelSelection::FeatureSetting
                                           .decorate(feature_settings)

            {
              ai_feature_settings: decorated_feature_settings,
              errors: errors
            }
          end

          private

          attr_reader :group_id

          def upsert_feature_setting(group, args)
            feature_setting = find_or_initialize_object(group, feature: args[:feature])

            ::Ai::ModelSelection::Namespace::UpdateService.new(
              feature_setting, current_user, args
            ).execute
          end

          def find_or_initialize_object(group, feature:)
            ::Ai::ModelSelection::NamespaceFeatureSetting.find_or_initialize_by_feature(group, feature)
          end
        end
      end
    end
  end
end
