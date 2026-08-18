# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['GoogleCloudImage'], feature_category: :runner_core do
  using RSpec::Parameterized::TableSyntax

  specify { expect(described_class.graphql_name).to eq('GoogleCloudImage') }

  describe '.coerce_input' do
    subject(:input) { described_class.coerce_isolated_input(image_name) }

    context 'when image name is valid' do
      where(:image_name) { %w[ubuntu windows_ltsc] }

      with_them do
        it 'coerces image name to same string' do
          expect(input).to eq(image_name)
        end
      end
    end

    context 'when image name is not valid' do
      let(:image_name) { '123' }

      it 'raises an exception' do
        expect { input }.to raise_error(GraphQL::CoercionError).with_message(%r{is not a valid image name})
      end
    end
  end

  describe '.coerce_result' do
    subject(:result) { described_class.coerce_isolated_result(:ubuntu) }

    it 'coerces a symbol to a string' do
      expect(result).to eq('ubuntu')
    end
  end
end
