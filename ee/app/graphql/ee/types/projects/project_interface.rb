# frozen_string_literal: true

module EE
  module Types
    module Projects
      module ProjectInterface
        extend ActiveSupport::Concern

        prepended do
          orphan_types ::Types::Projects::ProjectMinimalAccessType
        end

        class_methods do
          extend ::Gitlab::Utils::Override

          override :resolve_type
          def resolve_type(object, context)
            user = context[:current_user]

            return ::Types::ProjectType if user.can?(:read_project, object)
            return ::Types::Projects::ProjectMinimalAccessType if user.can?(:read_project_metadata, object)

            ::Types::ProjectType
          end
        end
      end
    end
  end
end
