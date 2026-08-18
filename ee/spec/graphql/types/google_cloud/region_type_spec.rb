# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudRegion'], feature_category: :runner_core do
  using RSpec::Parameterized::TableSyntax

  specify { expect(described_class.graphql_name).to eq('GoogleCloudRegion') }

  describe '.coerce_input' do
    subject(:input) { described_class.coerce_isolated_input(region_name) }

    context 'when region name is valid' do
      where(:region_name) { %w[us-west1 southamerica-west1] }

      with_them do
        it 'coerces region name to same string' do
          expect(input).to eq(region_name)
        end
      end
    end

    context 'when region name is not valid' do
      let(:region_name) { 'us-west1-a' }

      it 'raises an exception' do
        expect { input }.to raise_error(GraphQL::CoercionError).with_message(%r{is not a valid region name})
      end
    end
  end

  describe '.coerce_result' do
    subject(:result) { described_class.coerce_isolated_result(:'us-east1') }

    it 'coerces a symbol to a string' do
      expect(result).to eq('us-east1')
    end
  end
end
