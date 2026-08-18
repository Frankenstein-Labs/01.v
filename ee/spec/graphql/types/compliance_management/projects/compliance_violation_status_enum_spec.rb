# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceViolationStatus'], feature_category: :compliance_management do
  let(:fields) do
    %w[DETECTED IN_REVIEW RESOLVED DISMISSED]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceViolationStatus') }
  specify { expect(described_class.values.keys).to match_array(fields) }
end
