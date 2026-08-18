# frozen_string_literal: true

module Resolvers
  class PipelineSecurityReportFindingsResolver < BaseResolver
    type ::Types::PipelineSecurityReportFindingType, null: true

    alias_method :pipeline, :object

    argument :report_type, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerability findings by report type.'

    argument :severity, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerability findings by severity.'

    argument :scanner, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerability findings by Scanner.externalId.'

    argument :state, [Types::VulnerabilityStateEnum],
      required: false,
      description: 'Filter vulnerability findings by state.'

    argument :sort, Types::Security::PipelineSecurityReportFindingSortEnum,
      required: false,
      default_value: 'severity_desc',
      description: 'List vulnerability findings by sort order.'

    def resolve(**args)
      params = args.merge(
        limit: limit(args),
        cursor: ::Gitlab::Pagination::Keyset::GraphqlCursorBuilder.build(after: args[:after], before: args[:before])
      )

      ::Security::FindingsFinder.new(pipeline, params: params)
        .execute
    end

    private

    def limit(args)
      args[:first] || args[:last] || context.schema.default_max_page_size
    end
  end
end
