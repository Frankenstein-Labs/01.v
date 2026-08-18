# frozen_string_literal: true

module API
  module Entities
    module VirtualRegistries
      module Container
        class RegistryUpstream < Grape::Entity
          expose :id, :position
          expose :registry_id, unless: ->(_, options) { options[:exclude_registry_id] }
          expose :upstream_id, unless: ->(_, options) { options[:exclude_upstream_id] }
        end
      end
    end
  end
end
