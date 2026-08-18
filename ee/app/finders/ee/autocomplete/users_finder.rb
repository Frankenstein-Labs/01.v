# frozen_string_literal: true

module EE
  module Autocomplete # rubocop:disable Gitlab/BoundedContexts -- FOSS finder is not bounded to a context
    module UsersFinder
      extend ::Gitlab::Utils::Override
      include ::Gitlab::Utils::StrongMemoize

      attr_reader :preload_flow_triggers

      override :initialize
      def initialize(params:, current_user:, project:, group:)
        super
        @preload_flow_triggers = params.fetch(:preload_flow_triggers, false)
      end

      private

      override :project_users
      def project_users
        users = super

        if project.ai_review_merge_request_allowed?(current_user)
          duo_code_review_bot = ::Users::Internal.in_organization(current_user.organization_id).duo_code_review_bot
          users = users.union_with_user(duo_code_review_bot)
        end

        users
      end

      override :associations_to_preload
      def associations_to_preload
        associations = super
        associations.push(:ai_flow_triggers, :child_item_consumers_flow_triggers) if preload_flow_triggers
        associations
      end
    end
  end
end
