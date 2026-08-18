# frozen_string_literal: true

module Resolvers
  module Users
    class DuoStatusResolver < BaseResolver
      type ::Types::Users::DuoStatusType, null: true

      def self.single
        self
      end

      def resolve(**args)
        return unless object.service_account?
        return unless object.composite_identity_enforced?

        context[:duo_status_parent] = args[:parent]

        object
      end
    end
  end
end
