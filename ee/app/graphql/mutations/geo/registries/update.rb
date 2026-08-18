# frozen_string_literal: true

module Mutations
  module Geo
    module Registries
      class Update < BaseMutation
        graphql_name 'GeoRegistriesUpdate'
        description 'Mutates a Geo registry.'

        extend ::Gitlab::Utils::Override

        authorize :read_geo_registry
        authorize_granular_token permissions: :update_geo_registry, boundary: :instance, boundary_type: :instance

        argument :registry_id,
          Types::GlobalIDType[::Geo::BaseRegistry],
          required: true,
          description: 'ID of the Geo registry entry to be updated.'

        argument :action,
          ::Types::Geo::RegistryActionEnum,
          required: true,
          description: 'Action to be executed on a Geo registry.'

        field :registry, ::Types::Geo::RegistrableType, null: true, description: 'Updated Geo registry entry.'

        def resolve(action:, registry_id:)
          registry = authorized_find!(id: registry_id)

          result = ::Geo::RegistryUpdateService.new(action, registry).execute

          { registry: result.payload[:registry], errors: result.errors }
        end

        override :read_only?
        def read_only?
          false
        end
      end
    end
  end
end
