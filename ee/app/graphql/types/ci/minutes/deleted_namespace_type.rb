# frozen_string_literal: true

module Types
  module Ci
    module Minutes
      class DeletedNamespaceType < ::Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- Resolver auth
        graphql_name 'CiDeletedNamespace'
        description 'Reference to a namespace that no longer exists'

        DeletedNamespace = Struct.new(:raw_id) do
          def to_global_id
            ::Gitlab::GlobalId.build(model_name: ::Namespace.name, id: raw_id)
          end
        end

        field :id, ::Types::GlobalIDType[::Namespace], null: true,
          description: 'ID of the deleted namespace.'
      end
    end
  end
end
