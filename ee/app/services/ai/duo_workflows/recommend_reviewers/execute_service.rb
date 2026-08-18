# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module RecommendReviewers
      class ExecuteService
        def initialize(merge_request:, current_user:)
          @merge_request = merge_request
          @current_user = current_user
        end

        def execute
          ::Ai::DuoWorkflows::CreateAndStartWorkflowService.new(
            container: project,
            resource: merge_request,
            current_user: current_user,
            workflow_definition: ::Ai::Catalog::FoundationalFlow['recommend_reviewers/v1'],
            goal: merge_request.iid.to_s,
            source_branch: merge_request.source_branch
          ).execute
        end

        private

        attr_reader :merge_request, :current_user

        def project
          merge_request.project
        end
      end
    end
  end
end
