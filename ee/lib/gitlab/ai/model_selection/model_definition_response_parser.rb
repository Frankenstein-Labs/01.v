# frozen_string_literal: true

module Gitlab
  module Ai
    module ModelSelection
      class ModelDefinitionResponseParser
        include Gitlab::Utils::StrongMemoize

        def initialize(model_definitions)
          @definitions = model_definitions
        end

        attr_reader :definitions

        def model_with_ref(ref)
          return unless definitions

          gitlab_models_by_ref[ref]
        end

        def model_with_ref!(ref)
          model = model_with_ref(ref)

          raise ArgumentError, 'Model reference was not found in the model definition' unless model

          model
        end

        def definition_for_feature(feature)
          return unless definitions
          return unless model_definition_per_feature

          model_definition_per_feature[feature.to_s]
        end

        def default_model_ref_for_feature(feature)
          definition_for_feature(feature)&.fetch('default_model', nil)
        end

        def selectable_model_refs_for_feature(feature, include_dev: false)
          definition = definition_for_feature(feature)
          return [] unless definition

          selectable_model_refs_for_definition(definition, include_dev: include_dev)
        end

        def definitions_with_dev_selectable_models
          return unless definitions

          definitions.deep_dup.tap do |merged_definitions|
            merged_definitions['unit_primitives']&.each do |definition|
              next if definition.dig('dev', 'selectable_models').blank?

              feature = definition['feature_setting']
              definition['selectable_models'] = selectable_model_refs_for_feature(feature, include_dev: true)
            end
          end
        end

        def gitlab_models_by_ref
          return unless definitions && definitions['models']

          definitions['models'].to_h do |model|
            [
              model['identifier'],
              {
                'name' => model['name'],
                'ref' => model['identifier'],
                'model_provider' => model['provider'],
                'model_description' => model['description'],
                'cost_indicator' => model['cost_indicator']
              }
            ]
          end
        end
        strong_memoize_attr :gitlab_models_by_ref

        def model_definition_per_feature
          return unless definitions && definitions['unit_primitives']

          definitions['unit_primitives'].index_by { |up| up['feature_setting'] }
        end
        strong_memoize_attr :model_definition_per_feature

        def deprecated_models
          return unless definitions && definitions['models']

          definitions["models"].select do |model|
            model["deprecation"].present?
          end
        end
        strong_memoize_attr :deprecated_models

        def feature_deprecated_models(feature)
          definition = definition_for_feature(feature)
          return [] if definition.blank?

          Array(definition['deprecated_models']).filter_map do |feature_deprecation|
            model = models_by_ref[feature_deprecation['identifier']]
            next unless model

            model.merge('deprecation' => feature_deprecation.slice('deprecation_date', 'removal_version'))
          end
        end

        private

        def models_by_ref
          return {} unless definitions && definitions['models']

          definitions['models'].index_by { |model| model['identifier'] }
        end
        strong_memoize_attr :models_by_ref

        def selectable_model_refs_for_definition(definition, include_dev: false)
          refs = Array(definition.fetch('selectable_models', nil))
          refs += Array(definition.dig('dev', 'selectable_models')) if include_dev

          refs.reject(&:blank?).uniq
        end
      end
    end
  end
end
