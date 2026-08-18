# frozen_string_literal: true

module Types
  module VirtualRegistries
    module Packages
      module Maven
        class RegistryUpstreamWithUpstreamType < ::Types::BaseObject
          graphql_name 'MavenRegistryUpstreamWithUpstream'
          description 'Represents a Maven virtual registry upstream and its relationship to the upstream.'

          authorize :read_virtual_registry

          implements Types::VirtualRegistries::RegistryUpstreamInterface

          field :upstream, ::Types::VirtualRegistries::Packages::Maven::UpstreamType, null: false,
            description: 'Maven upstream associated with the registry upstream.',
            experiment: { milestone: '18.7' }

          def upstream
            Gitlab::Graphql::Loaders::BatchModelLoader.new(
              ::VirtualRegistries::Packages::Maven::Upstream,
              object.upstream_id
            ).find
          end
        end
      end
    end
  end
end
