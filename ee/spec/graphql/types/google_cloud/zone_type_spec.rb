# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudZone'], feature_category: :runner_core do
  using RSpec::Parameterized::TableSyntax

  specify { expect(described_class.graphql_name).to eq('GoogleCloudZone') }

  describe '.coerce_input' do
    subject(:input) { described_class.coerce_isolated_input(zone_name) }

    context 'when zone name is valid' do
      where(:zone_name) { %w[northamerica-northeast2-c africa-south1-c] }

      with_them do
        it 'coerces zone name to same string' do
          expect(input).to eq(zone_name)
        end
      end
    end

    context 'when zone name is not valid' do
      let(:zone_name) { 'us-west1-a1' }

      it 'raises an exception' do
        expect { input }.to raise_error(GraphQL::CoercionError).with_message(%r{is not a valid zone name})
      end
    end
  end

  describe '.coerce_result' do
    subject(:result) { described_class.coerce_isolated_result(:'us-east1-a') }

    it 'coerces a symbol to a string' do
      expect(result).to eq('us-east1-a')
    end
  end
end
