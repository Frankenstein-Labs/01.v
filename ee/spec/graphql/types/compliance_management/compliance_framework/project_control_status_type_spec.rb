# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ProjectComplianceControlStatusType'], feature_category: :compliance_management do
  let(:fields) do
    %i[id updated_at status compliance_requirements_control]
  end

  specify { expect(described_class.graphql_name).to eq('ProjectComplianceControlStatusType') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
