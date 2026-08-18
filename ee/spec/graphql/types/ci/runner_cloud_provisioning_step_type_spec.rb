# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiRunnerCloudProvisioningStep'], feature_category: :fleet_visibility do
  specify do
    expect(described_class.description).to eq('Step used to provision the runner to Google Cloud.')
  end

  it 'includes all expected fields' do
    expected_fields = %w[title instructions language_identifier]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
