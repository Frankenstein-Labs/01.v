# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectComplianceViolation'], feature_category: :compliance_management do
  let(:fields) do
    %i[id created_at project compliance_control status audit_event notes discussions commenters issues web_url name]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectComplianceViolation') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:read_compliance_violations_report) }
end
