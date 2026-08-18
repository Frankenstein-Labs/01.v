# frozen_string_literal: true

module Vulnerabilities
  module Exports
    class BatchDestroyService
      include BaseServiceUtility

      def initialize(exports:)
        @exports = exports
      end

      def execute
        return if exports.blank?

        exports.each_batch do |batch|
          batch.tap { |exports| Upload.destroy_for_associations!(exports) }
               .delete_all
        end
      end

      private

      attr_reader :exports, :only_expired
    end
  end
end
