# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectComplianceControlStatus'], feature_category: :compliance_management do
  let(:fields) do
    %w[PASS FAIL PENDING]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectComplianceControlStatus') }
  specify { expect(described_class.values.keys).to match_array(fields) }
end
