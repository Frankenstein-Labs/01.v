# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceStandardsProjectAdherenceInput'], feature_category: :compliance_management do
  let(:arguments) do
    %w[checkName standard]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceStandardsProjectAdherenceInput') }
  specify { expect(described_class.arguments.keys).to match_array(arguments) }
end
