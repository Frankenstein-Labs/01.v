# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ComplianceFrameworksNeedingAttention'], feature_category: :compliance_management do
  let(:fields) do
    %i[id framework projects_count requirements_count requirements_without_controls]
  end

  specify { expect(described_class.graphql_name).to eq('ComplianceFrameworksNeedingAttention') }
  specify { expect(described_class).to have_graphql_fields(fields) }
end
