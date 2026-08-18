# frozen_string_literal: true

module API
  module Entities
    module VirtualRegistries
      module Container
        class Registry < Grape::Entity
          expose :id, :name, :description, :group_id, :created_at, :updated_at
          expose :registry_upstreams,
            if: ->(_registry, options) { options[:with_registry_upstreams] },
            using: RegistryUpstream
        end
      end
    end
  end
end
