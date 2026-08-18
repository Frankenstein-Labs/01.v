# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::ScanProfiles::AutoRemediationConfigurationType, feature_category: :security_testing_configuration do
  it { expect(described_class.graphql_name).to eq('AutoRemediationConfiguration') }

  it 'exposes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :enabled,
      :cooldown,
      :severity_level,
      :upgrade_policy,
      :open_merge_requests_limit,
      :runner_tags
    )
  end
end
