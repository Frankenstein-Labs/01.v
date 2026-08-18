# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['LicensedFeatureAvailability'], feature_category: :subscription_management do
  it { expect(described_class.graphql_name).to eq('LicensedFeatureAvailability') }

  it 'has expected fields' do
    expect(described_class).to have_graphql_fields(:available, :required_plan)
  end
end
