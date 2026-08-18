# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceViolation'], feature_category: :compliance_management do
  let(:fields) do
    %i[id severity_level reason violating_user merge_request]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceViolation') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:read_compliance_violations_report) }
end
