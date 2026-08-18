# frozen_string_literal: true

module EE
  module Mcp
    module Tools
      module Base
        module GraphqlTool
          extend ActiveSupport::Concern

          EE_QUERIES_ROOT = Rails.root.join('ee/app/graphql/queries/mcp').freeze

          class_methods do
            extend ::Gitlab::Utils::Override

            override :load_graphql
            def load_graphql(relative_path)
              ee_query_path = EE_QUERIES_ROOT.join(relative_path)

              return read_query_file(ee_query_path) if ee_query_exist?(ee_query_path)

              super
            end

            private

            def ee_query_exist?(query_path)
              File.exist?(query_path)
            end

            def read_query_file(query_path)
              File.read(query_path).freeze
            end
          end
        end
      end
    end
  end
end
