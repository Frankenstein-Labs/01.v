# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a project\'s security scan profiles', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }

  let(:trigger_settings_selection) do
    <<~SELECTION
      name
      triggerSettings {
        triggerType
        configuration {
          __typename
          ... on AutoRemediationConfiguration { cooldown severityLevel upgradePolicy }
        }
      }
    SELECTION
  end

  let(:query) do
    graphql_query_for(:project, { full_path: project.full_path },
      query_graphql_field(:security_scan_profiles, {}, trigger_settings_selection))
  end

  let(:profiles_data) { graphql_data_at(:project, :security_scan_profiles) }

  def attach_profile_with_trigger(name)
    profile = create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group, name: name)
    create(:security_scan_profile_project, scan_profile: profile, project: project)
    create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :sbom_ingested,
      configuration_values: { 'auto_remediation' => { 'severity_level' => 'critical' } })
    profile
  end

  before do
    stub_licensed_features(security_scan_profiles: true)
    attach_profile_with_trigger('Profile 1')
  end

  it 'returns the effective trigger configuration for each attached profile' do
    post_graphql(query, current_user: user)

    config = profiles_data.dig(0, 'triggerSettings', 0, 'configuration')

    expect(config['__typename']).to eq('AutoRemediationConfiguration')
    expect(config).to include(
      'severityLevel' => 'CRITICAL', # persisted override
      'cooldown' => 7,               # merged default
      'upgradePolicy' => 'MINOR'     # merged default
    )
  end

  it 'computes the effective configuration scoped to the project so project-specific overrides apply' do
    allow(Security::ScanProfiles::Configuration).to receive(:effective_for).and_call_original

    post_graphql(query, current_user: user)

    expect(graphql_errors).to be_nil
    expect(Security::ScanProfiles::Configuration)
      .to have_received(:effective_for).with(anything, anything, project: an_instance_of(Project)).at_least(:once)
  end

  it 'avoids N+1 queries as the number of attached profiles grows' do
    post_graphql(query, current_user: user) # warm up before recording the control
    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }
    expect(profiles_data).to be_present

    attach_profile_with_trigger('Profile 2')
    attach_profile_with_trigger('Profile 3')

    expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
  end
end
