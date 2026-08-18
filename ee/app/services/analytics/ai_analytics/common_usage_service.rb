# frozen_string_literal: true

module Analytics
  module AiAnalytics
    module CommonUsageService
      include Gitlab::Utils::StrongMemoize

      def initialize(current_user, namespace:, from:, to:, fields: nil)
        @current_user = current_user
        @namespace = namespace
        @from = from
        @to = to
        @fields = (fields & self.class::FIELDS) || self.class::FIELDS
      end

      def execute
        return feature_unavailable_error unless Gitlab::ClickHouse.enabled_for_analytics?(namespace)
        return ServiceResponse.success(payload: empty_payload) unless fields.present?

        ServiceResponse.success(payload: success_payload)
      end

      private

      attr_reader :current_user, :namespace, :from, :to, :fields

      def success_payload
        usage_data.symbolize_keys!
      end

      def empty_payload
        {}
      end

      def feature_unavailable_error
        ServiceResponse.error(
          message: s_('AiAnalytics|the ClickHouse data store is not available')
        )
      end

      def placeholders
        {
          traversal_path: namespace.traversal_path(with_organization: false),
          from: from.to_date.iso8601,
          to: to.to_date.iso8601
        }
      end
      strong_memoize_attr :placeholders

      def usage_data
        query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)

        ClickHouse::Client.select(query, :main).first
      end

      def raw_query
        raw_fields = fields.map do |field|
          "(#{self.class::FIELDS_SUBQUERIES[field]}) as #{field}"
        end.join(',')

        format(self.class::QUERY, fields: raw_fields)
      end
    end
  end
end
