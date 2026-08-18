# frozen_string_literal: true

module EE
  module Resolvers
    module GroupsResolver # rubocop:disable Gitlab/BoundedContexts -- EE extension of CE GroupsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :with_knowledge_graph_enabled, GraphQL::Types::Boolean,
          required: false,
          default_value: false,
          experiment: { milestone: '18.10' },
          description: 'Return only groups with Knowledge Graph enabled.'
      end
    end
  end
end
