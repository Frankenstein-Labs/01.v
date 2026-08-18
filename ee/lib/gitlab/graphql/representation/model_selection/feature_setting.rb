# frozen_string_literal: true

module Gitlab
  module Graphql
    module Representation
      module ModelSelection
        class FeatureSetting < SimpleDelegator
          class << self
            def decorate(feature_settings, model_definitions: nil, current_user: nil)
              return [] unless feature_settings.present?

              feature_settings.filter_map do |feature_setting|
                decorator = new(feature_setting,
                  model_definitions: model_definitions,
                  current_user: current_user
                )

                next if decorator.feature_data.nil?

                if model_definitions.present? || feature_setting.try(:model_definitions).present?
                  decorator.decorate_default_model

                  decorator.decorate_selectable_models

                  decorator.decorate_allow_list
                end

                next decorator
              end
            end
          end

          attr_accessor :feature_setting, :default_model, :selectable_models, :allow_list, :model_definitions
          attr_reader :current_user

          def initialize(feature_setting, model_definitions: nil, current_user: nil)
            @feature_setting = feature_setting
            @model_definitions = model_definitions || feature_setting.try(:model_definitions)
            @current_user = current_user
            super(feature_setting)
          end

          def feature_data
            return if model_definitions.blank?

            @feature_data ||= model_definition_parser.definition_for_feature(feature_setting.feature)
          end

          def decorate_default_model
            model_ref = model_definition_parser.default_model_ref_for_feature(feature_setting.feature)
            model_data = find_single_model_data(model_ref)
            @default_model = model_data.presence
          end

          def decorate_selectable_models
            model_refs = model_definition_parser.selectable_model_refs_for_feature(
              feature_setting.feature,
              include_dev: use_dev_overrides?
            )
            @selectable_models = model_refs.map { |model_ref| find_single_model_data(model_ref) }
          end

          def decorate_allow_list
            return unless feature_setting.model_allowlist_supported?

            @allow_list = ::Gitlab::Graphql::Representation::ModelSelection::AllowListPayload.build(
              feature_setting: feature_setting,
              model_definition_parser: model_definition_parser,
              offered_models: selectable_models,
              group: feature_setting.try(:namespace)
            )
          end

          private

          def use_dev_overrides?
            return false unless Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
            return false unless current_user&.gitlab_team_member?

            dev_config.present?
          end

          def find_single_model_data(model_ref)
            model_definition_parser.model_with_ref!(model_ref).symbolize_keys
          end

          def model_definition_parser
            @model_definition_parser ||= ::Gitlab::Ai::ModelSelection::ModelDefinitionResponseParser.new(
              model_definitions
            )
          end

          def dev_config
            @dev_config ||= feature_data['dev']
          end
        end
      end
    end
  end
end
