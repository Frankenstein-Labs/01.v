# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::SpdxLicenseType, feature_category: :dependency_management do
  include GraphqlHelpers

  let(:fields) { %i[name spdx_identifier url] }

  it { expect(described_class).to have_graphql_fields(fields) }

  describe '#url' do
    subject(:url) { resolve_field(:url, license) }

    context 'when the license is the "unknown" placeholder' do
      let(:license) { ::Gitlab::SPDX::License.unknown }

      it { is_expected.to be_nil }
    end

    context 'when the license is a real SPDX license' do
      let(:license) { ::Gitlab::SPDX::License.new(id: 'MIT', name: 'MIT License') }

      it { is_expected.to eq('https://spdx.org/licenses/MIT.html') }
    end
  end
end
