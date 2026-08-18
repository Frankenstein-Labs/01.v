# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ScanModeEnum'], feature_category: :vulnerability_management do
  specify { expect(described_class.graphql_name).to eq('ScanModeEnum') }

  describe 'statuses' do
    using RSpec::Parameterized::TableSyntax

    where(:graphql_value, :param_value) do
      'ALL'     | 'all'
      'FULL'    | 'full'
      'PARTIAL' | 'partial'
    end

    with_them do
      it 'exposes a status with the correct value' do
        expect(described_class.values[graphql_value].value).to eq(param_value)
      end
    end
  end
end
