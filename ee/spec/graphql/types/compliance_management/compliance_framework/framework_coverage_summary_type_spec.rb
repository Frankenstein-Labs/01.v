# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceFrameworkCoverageSummary'], feature_category: :compliance_management do
  let(:fields) do
    %i[total_projects covered_count]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceFrameworkCoverageSummary') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
