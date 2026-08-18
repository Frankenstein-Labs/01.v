# frozen_string_literal: true

module API
  module Entities
    module WorkItems
      module Features
        class FeatureFlag < Grape::Entity
          expose :id, documentation: { type: 'Integer', example: 1 }
          expose :name, documentation: { type: 'String', example: 'my_feature_flag' }
          expose :active, documentation: { type: 'Boolean', example: true }
          expose :path, documentation: { type: 'String', example: '/group/project/-/feature_flags/1/edit' }
          expose :reference, documentation: { type: 'String', example: '[feature_flag:1]' } do |flag, options|
            flag.to_reference(options[:reference_from])
          end
        end
      end
    end
  end
end
