# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectComplianceRequirementStatus'], feature_category: :compliance_management do
  let(:fields) do
    %i[id updated_at pass_count fail_count pending_count project compliance_requirement compliance_framework]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectComplianceRequirementStatus') }
  specify { expect(described_class).to have_graphql_fields(fields) }
  specify { expect(described_class).to require_graphql_authorizations(:read_compliance_adherence_report) }
end
