# frozen_string_literal: true

module Ai
  module ModelSelection
    class DefaultDuoNamespaceService
      include Ai::ModelSelection::SelectionApplicable

      def initialize(user)
        @user = user
      end

      private

      attr_reader :user

      def current_user
        user
      end
    end
  end
end
