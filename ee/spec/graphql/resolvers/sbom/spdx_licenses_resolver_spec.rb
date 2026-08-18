# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Sbom::SpdxLicensesResolver, :clean_gitlab_redis_cache, feature_category: :dependency_management do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) { resolve(described_class, ctx: { current_user: current_user }) }

    context 'when user is authenticated' do
      let_it_be(:current_user) { create(:user) }

      it 'returns licenses sorted by name' do
        licenses = result

        expect(licenses).to be_an(Array)
        expect(licenses.map(&:name)).to eq(licenses.map(&:name).sort)
      end

      describe 'included licenses' do
        using RSpec::Parameterized::TableSyntax

        where(:case_name, :id, :name, :spdx_identifier) do
          'unknown license'        | 'unknown' | 'Unknown'                              | 'unknown'
          'SPDX catalogue license' | 'MIT'     | 'MIT License'                          | 'MIT'
          'deprecated license'     | 'GPL-1.0' | 'GNU General Public License v1.0 only' | 'GPL-1.0'
        end

        with_them do
          it 'includes the expected license' do
            license = result.find { |l| l.id == id }

            expect(license).to have_attributes(
              name: name,
              spdx_identifier: spdx_identifier,
              url: "https://spdx.org/licenses/#{spdx_identifier}.html"
            )
          end
        end
      end
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          result
        end
      end
    end
  end
end
