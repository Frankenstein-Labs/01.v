# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateCheckpointWriteBatchService
      include ::Services::ReturnServiceResponses

      def initialize(workflow:, params:)
        @workflow = workflow
        @params = params
      end

      def execute
        @workflow.checkpoint_writes.bulk_insert!(writes_batch)
        success({})
      rescue ActiveRecord::RecordInvalid => err
        error(err.message, :bad_request)
      end

      private

      def writes_batch
        @params[:checkpoint_writes].map do |attrs|
          @workflow.checkpoint_writes.new(
            attrs.merge(thread_ts: @params[:thread_ts])
          )
        end
      end
    end
  end
end
