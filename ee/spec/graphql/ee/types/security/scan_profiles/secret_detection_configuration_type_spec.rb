# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfiles::SecretDetectionConfigurationType, feature_category: :security_testing_configuration do
  it { expect(described_class.graphql_name).to eq('SecretDetectionConfiguration') }

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :secure_analyzers_prefix,
      :image_suffix,
      :historic_scan,
      :log_options,
      :excluded_paths,
      :ruleset_git_reference
    )
  end
end
