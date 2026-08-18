# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudMachineType'], feature_category: :runner_core do
  using RSpec::Parameterized::TableSyntax

  specify { expect(described_class.graphql_name).to eq('GoogleCloudMachineType') }

  describe '.coerce_input' do
    subject(:input) { described_class.coerce_isolated_input(machine_type_name) }

    context 'when machine type name is valid' do
      where(:machine_type_name) do
        %w[ct5p-hightpu-2t n2d-standard-2 c3d-standard-360-lssd]
      end

      with_them do
        it 'coerces machine type name to same string' do
          expect(input).to eq(machine_type_name)
        end
      end
    end

    context 'when machine type name is not valid' do
      let(:machine_type_name) { 't2a-standard_1' }

      it 'raises an exception' do
        expect { input }.to raise_error(GraphQL::CoercionError).with_message(%r{is not a valid machine type name})
      end
    end
  end

  describe '.coerce_result' do
    subject(:result) { described_class.coerce_isolated_result(:'c2d-highcpu-112') }

    it 'coerces a symbol to a string' do
      expect(result).to eq('c2d-highcpu-112')
    end
  end
end
