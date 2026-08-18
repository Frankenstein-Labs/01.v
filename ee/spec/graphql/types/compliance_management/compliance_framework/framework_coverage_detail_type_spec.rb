# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceFrameworkCoverageDetail'], feature_category: :compliance_management do
  let(:fields) do
    %i[id framework covered_count]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceFrameworkCoverageDetail') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
