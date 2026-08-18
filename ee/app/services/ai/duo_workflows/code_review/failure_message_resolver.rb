# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class FailureMessageResolver
        KNOWN_FAILURE_MESSAGES = {
          flow_not_enabled: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.foundational_flow_not_enabled_error
          },
          invalid_service_account: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.missing_service_account_error
          },
          usage_quota_exceeded: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.usage_quota_exceeded_error
          },
          usage_billing_forbidden: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.usage_billing_forbidden_error
          },
          namespace_missing: ->(user) {
            ::Gitlab::Duo::CodeReview::Messages.namespace_missing_error(user)
          },
          cannot_create_workflow_pipeline: ->(user) {
            ::Gitlab::Duo::CodeReview::Messages.insufficient_workload_permissions_error(user)
          },
          workload_failure: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.workload_creation_error
          },
          workflow_workload_failure: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.workload_creation_error
          },
          feature_unavailable: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.feature_unavailable_error
          },
          invalid_duo_workflow_token: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.invalid_token_error
          },
          invalid_oauth_token: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.invalid_token_error
          },
          source_ref_not_found: ->(_user) {
            ::Gitlab::Duo::CodeReview::Messages.source_ref_not_found_error
          }
        }.freeze

        DEFAULT_FAILURE_MESSAGE = ->(_user) {
          ::Gitlab::Duo::CodeReview::Messages.could_not_start_workflow_error
        }

        def initialize(user:)
          @user = user
        end

        def resolve(reason)
          KNOWN_FAILURE_MESSAGES.fetch(reason, DEFAULT_FAILURE_MESSAGE).call(user)
        end

        def known_reason?(reason)
          KNOWN_FAILURE_MESSAGES.key?(reason)
        end

        private

        attr_reader :user
      end
    end
  end
end
