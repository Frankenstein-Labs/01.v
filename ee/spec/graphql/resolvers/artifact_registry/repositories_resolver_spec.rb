# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ArtifactRegistry::RepositoriesResolver, feature_category: :artifact_registry do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:current_user) { create(:organization_user, organization: organization).user }

  let(:page) { ArtifactRegistry::Page.new(nodes: []) }
  let(:client) { instance_double(ArtifactRegistry::Client, repositories: page) }
  let(:slug) { Organizations::ArtifactRegistry::STUB_SLUG }
  let(:max_page_size) { GitlabSchema.default_max_page_size }
  let(:default_sort) { { sort: 'last_updated_at', order: 'desc' } }
  let(:args) { {} }

  before do
    allow(organization).to receive(:artifact_registry_client).with(current_user: current_user).and_return(client)
  end

  subject(:resolve_repositories) do
    resolve(
      described_class,
      obj: organization,
      args: args,
      ctx: { current_user: current_user },
      field_opts: { connection_extension: ::Gitlab::Graphql::Extensions::ExternallyPaginatedArrayExtension }
    )
  end

  it "reads the organization's resolved slug at the schema's default page size" do
    resolve_repositories

    expect(client).to have_received(:repositories).with(slug: slug, limit: max_page_size, **default_sort)
  end

  context 'with a requested page size below the maximum' do
    let(:args) { { first: 10 } }

    it 'forwards the requested size as the outbound limit' do
      resolve_repositories

      expect(client).to have_received(:repositories).with(slug: slug, limit: 10, **default_sort)
    end
  end

  context 'with a requested page size above the maximum' do
    let(:args) { { first: GitlabSchema.default_max_page_size + 1 } }

    it 'caps the outbound limit at the maximum' do
      resolve_repositories

      expect(client).to have_received(:repositories).with(slug: slug, limit: max_page_size, **default_sort)
    end
  end

  it 'sends no filter when neither is requested' do
    resolve_repositories

    expect(client).to have_received(:repositories).with(hash_not_including(:format, :kind))
  end

  context 'with a format filter' do
    ::Types::ArtifactRegistry::RepositoryFormatEnum.values.each_value do |enum_value|
      context "for #{enum_value.graphql_name}" do
        let(:args) { { format: enum_value.value } }

        it 'forwards the wire value the contract expects' do
          resolve_repositories

          expect(client).to have_received(:repositories)
            .with(slug: slug, format: enum_value.value, limit: max_page_size, **default_sort)
        end
      end
    end
  end

  context 'with a kind filter' do
    ::Types::ArtifactRegistry::RepositoryKindEnum.values.each_value do |enum_value|
      context "for #{enum_value.graphql_name}" do
        let(:args) { { kind: enum_value.value } }

        it 'forwards the wire value the contract expects' do
          resolve_repositories

          expect(client).to have_received(:repositories)
            .with(slug: slug, kind: enum_value.value, limit: max_page_size, **default_sort)
        end
      end
    end
  end

  context 'with both filters and a page size' do
    let(:args) { { format: 'maven', kind: 'hosted', first: 10 } }

    it 'forwards both alongside the outbound limit' do
      resolve_repositories

      expect(client).to have_received(:repositories)
        .with(slug: slug, format: 'maven', kind: 'hosted', limit: 10, **default_sort)
    end
  end

  context 'when paging forward' do
    let(:args) { { first: 10, after: 'NEXT_CURSOR' } }

    it 'forwards the forward cursor' do
      resolve_repositories

      expect(client).to have_received(:repositories)
        .with(slug: slug, limit: 10, cursor: 'NEXT_CURSOR', **default_sort)
    end
  end

  context 'when paging backward' do
    let(:args) { { last: 5, before: 'PREV_CURSOR' } }

    it 'forwards the backward cursor' do
      resolve_repositories

      expect(client).to have_received(:repositories)
        .with(slug: slug, limit: 5, cursor: 'PREV_CURSOR', **default_sort)
    end
  end

  describe 'the sort argument' do
    using RSpec::Parameterized::TableSyntax

    where(:sort_name, :expected_sort, :expected_order) do
      'NAME_ASC'             | 'name'            | 'asc'
      'NAME_DESC'            | 'name'            | 'desc'
      'LAST_UPDATED_AT_ASC'  | 'last_updated_at' | 'asc'
      'LAST_UPDATED_AT_DESC' | 'last_updated_at' | 'desc'
      'DOWNLOADS_COUNT_ASC'  | 'downloads_count' | 'asc'
      'DOWNLOADS_COUNT_DESC' | 'downloads_count' | 'desc'
      'SIZE_BYTES_ASC'       | 'size_bytes'      | 'asc'
      'SIZE_BYTES_DESC'      | 'size_bytes'      | 'desc'
    end

    with_them do
      let(:args) { { sort: sort_name } }

      it 'reaches the client as the column and direction the contract expects' do
        resolve_repositories

        expect(client).to have_received(:repositories)
          .with(slug: slug, limit: max_page_size, sort: expected_sort, order: expected_order)
      end
    end

    context 'when the argument is explicitly null' do
      let(:args) { { sort: nil } }

      it 'reaches the client as the default column and direction' do
        resolve_repositories

        expect(client).to have_received(:repositories).with(slug: slug, limit: max_page_size, **default_sort)
      end
    end
  end
end
