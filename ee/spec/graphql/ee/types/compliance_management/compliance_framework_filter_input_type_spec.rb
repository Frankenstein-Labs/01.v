# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Types::ComplianceManagement::ComplianceFrameworkFilterInputType, feature_category: :compliance_management do
  it { expect(described_class.graphql_name).to eq('ComplianceFrameworkFilters') }

  it { expect(described_class.arguments.keys).to match_array(%w[id ids not presenceFilter]) }
end
