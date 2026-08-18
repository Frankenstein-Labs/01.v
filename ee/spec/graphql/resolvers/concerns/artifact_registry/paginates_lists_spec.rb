# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ArtifactRegistry::PaginatesLists, feature_category: :artifact_registry do
  let(:adapter_class) do
    Class.new do
      include ::ArtifactRegistry::PaginatesLists

      attr_accessor :field

      def pagination(**args)
        artifact_registry_pagination(**args)
      end

      def connection(page)
        artifact_registry_connection(page)
      end
    end
  end

  subject(:adapter) { adapter_class.new }

  describe '#artifact_registry_pagination' do
    using RSpec::Parameterized::TableSyntax

    where(:args, :max_page_size, :expected) do
      { first: 10, after: 'CURSOR' } | nil | { limit: 10, cursor: 'CURSOR' }
      { last: 5, before: 'PREV' }    | nil | { limit: 5, cursor: 'PREV' }
      {}                             | nil | { limit: GitlabSchema.default_max_page_size }
      { first: 50 }                  | 20  | { limit: 20 }
    end

    with_them do
      it 'maps connection arguments to client pagination' do
        adapter.field = instance_double(Types::BaseField, max_page_size: max_page_size) if max_page_size

        expect(adapter.pagination(**args)).to eq(expected)
      end
    end

    it 'rejects an unanchored last, which would silently serve the first page' do
      expect { adapter.pagination(last: 20) }
        .to raise_error(Gitlab::Graphql::Errors::ArgumentError, '`last` requires `before`')
    end
  end

  describe '#artifact_registry_connection' do
    let(:repositories) { [instance_double(ArtifactRegistry::Repository)] }

    it 'wraps a page as an ExternallyPaginatedArray exposing pageInfo from the cursors', :aggregate_failures do
      page = ArtifactRegistry::Page.new(
        nodes: repositories, next_cursor: 'NEXT', prev_cursor: 'PREV'
      )

      connection = adapter.connection(page)

      expect(connection).to be_a(Gitlab::Graphql::ExternallyPaginatedArray)
      expect(connection.to_a).to eq(repositories)
      expect(connection.start_cursor).to eq('PREV')
      expect(connection.end_cursor).to eq('NEXT')
      expect(connection.has_next_page).to be(true)
      expect(connection.has_previous_page).to be(true)
    end

    it 'reports no adjacent pages when the client returns no cursors', :aggregate_failures do
      page = ArtifactRegistry::Page.new(nodes: repositories)

      connection = adapter.connection(page)

      expect(connection.has_next_page).to be(false)
      expect(connection.has_previous_page).to be(false)
    end
  end
end
