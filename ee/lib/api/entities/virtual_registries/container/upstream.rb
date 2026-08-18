# frozen_string_literal: true

module API
  module Entities
    module VirtualRegistries
      module Container
        class Upstream < Grape::Entity
          expose :id, :name, :description, :group_id, :url, :username, :cache_validity_hours, :created_at, :updated_at
          expose :registry_upstream,
            if: ->(_upstream, options) { options[:with_registry_upstream] },
            using: RegistryUpstream
          expose :registry_upstreams,
            if: ->(_upstream, options) { options[:with_registry_upstreams] },
            using: RegistryUpstream

          private

          # When with_registry_upstream option is true, it's guaranteed
          # that the object.registry_upstreams is a one-element array.
          def registry_upstream
            object.registry_upstreams.first
          end
        end
      end
    end
  end
end
