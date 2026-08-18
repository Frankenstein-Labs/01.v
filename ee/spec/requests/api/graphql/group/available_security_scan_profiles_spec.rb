# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying available security scan profiles', feature_category: :security_testing_configuration do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let_it_be(:scan_profile) do
    create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group)
  end

  let_it_be(:trigger) do
    create(:security_scan_profile_trigger, scan_profile: scan_profile, trigger_type: :sbom_ingested,
      configuration_values: { 'auto_remediation' => { 'severity_level' => 'critical' } })
  end

  let(:profiles_field) do
    query_graphql_field(
      :available_security_scan_profiles,
      { type: :DEPENDENCY_SCANNING_POST_PROCESSING },
      'configuration'
    )
  end

  let(:query) do
    graphql_query_for(:group, { full_path: group.full_path }, profiles_field)
  end

  def create_post_processing_profile(name)
    profile = create(:security_scan_profile, :dependency_scanning_post_processing, namespace: group, name: name)
    create(:security_scan_profile_trigger, scan_profile: profile, trigger_type: :sbom_ingested,
      configuration_values: { 'auto_remediation' => { 'severity_level' => 'high' } })
    profile
  end

  before_all do
    group.add_developer(user)
  end

  before do
    stub_licensed_features(security_scan_profiles: true)
  end

  it 'returns the effective configuration, merging the persisted override with defaults' do
    post_graphql(query, current_user: user)

    configuration = graphql_data_at(:group, :available_security_scan_profiles, 0, :configuration)

    expect(configuration).to include(
      'auto_remediation' => a_hash_including(
        'severity_level' => 'critical',
        'cooldown' => 7
      )
    )
  end

  it 'does not run additional queries as the number of profiles grows' do
    post_graphql(query, current_user: user) # warm up before recording the control
    control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }
    expect(graphql_data_at(:group, :available_security_scan_profiles)).to be_present

    create_post_processing_profile('second profile')
    create_post_processing_profile('third profile')

    expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
  end

  describe 'triggerSettings' do
    let(:trigger_settings_selection) do
      <<~SELECTION
        triggerType
        configuration {
          __typename
          ... on AutoRemediationConfiguration {
            enabled
            cooldown
            severityLevel
            upgradePolicy
            openMergeRequestsLimit
            runnerTags
          }
          ... on SecretDetectionConfiguration {
            historicScan
            imageSuffix
          }
        }
      SELECTION
    end

    def profiles_with_trigger_settings(type)
      graphql_query_for(:group, { full_path: group.full_path },
        query_graphql_field(
          :available_security_scan_profiles, { type: type },
          query_graphql_field(:trigger_settings, {}, trigger_settings_selection)
        ))
    end

    it 'exposes the trigger with its strongly-typed effective auto-remediation configuration' do
      post_graphql(profiles_with_trigger_settings(:DEPENDENCY_SCANNING_POST_PROCESSING), current_user: user)

      settings = graphql_data_at(:group, :available_security_scan_profiles, 0, :trigger_settings)
      setting = settings.find { |s| s['triggerType'] == 'SBOM_INGESTED' }

      configuration = setting['configuration']

      expect(configuration['__typename']).to eq('AutoRemediationConfiguration')
      expect(configuration).to include(
        'severityLevel' => 'CRITICAL', # persisted override
        'cooldown' => 7,               # merged default
        'upgradePolicy' => 'MINOR'     # merged default
      )
    end

    context 'with a secret detection profile' do
      let_it_be(:secret_detection_profile) do
        create(:security_scan_profile, namespace: group, scan_type: :secret_detection, name: 'SD')
      end

      let_it_be(:secret_detection_trigger) do
        create(:security_scan_profile_trigger, scan_profile: secret_detection_profile,
          trigger_type: :default_branch_pipeline,
          configuration_values: { 'historic_scan' => true, 'image_suffix' => '-fips' })
      end

      it 'exposes the strongly-typed secret detection configuration' do
        post_graphql(profiles_with_trigger_settings(:SECRET_DETECTION), current_user: user)

        settings = graphql_data_at(:group, :available_security_scan_profiles, 0, :trigger_settings)
        configuration = settings.first['configuration']

        expect(configuration['__typename']).to eq('SecretDetectionConfiguration')
        expect(configuration).to include(
          'historicScan' => true,
          'imageSuffix' => 'FIPS'
        )
      end

      it 'does not run additional queries as the number of triggers on a profile grows' do
        query = profiles_with_trigger_settings(:SECRET_DETECTION)
        post_graphql(query, current_user: user) # warm up before recording the control
        control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: user) }

        # ScanProfiles::ConfigurationType.resolve_type reads `object.scan_profile` per trigger; the `inverse_of` on
        # the trigger's `belongs_to :scan_profile` keeps that in memory, so adding triggers to a
        # single profile must not add queries.
        create(:security_scan_profile_trigger, scan_profile: secret_detection_profile,
          trigger_type: :git_push_event)
        create(:security_scan_profile_trigger, scan_profile: secret_detection_profile,
          trigger_type: :merge_request_pipeline,
          configuration_values: { 'historic_scan' => true })

        expect { post_graphql(query, current_user: user) }.not_to exceed_query_limit(control)
      end
    end

    context 'with a scan type that has no typed configuration' do
      let_it_be(:sast_profile) do
        create(:security_scan_profile, namespace: group, scan_type: :sast, name: 'SAST')
      end

      let_it_be(:sast_trigger) do
        create(:security_scan_profile_trigger, scan_profile: sast_profile, trigger_type: :default_branch_pipeline)
      end

      it 'returns a null configuration instead of failing to resolve the union' do
        post_graphql(profiles_with_trigger_settings(:SAST), current_user: user)

        expect(graphql_errors).to be_nil

        settings = graphql_data_at(:group, :available_security_scan_profiles, 0, :trigger_settings)
        expect(settings.first['configuration']).to be_nil
      end
    end

    it 'does not run additional queries as the number of profiles grows' do
      trigger_query = profiles_with_trigger_settings(:DEPENDENCY_SCANNING_POST_PROCESSING)
      post_graphql(trigger_query, current_user: user) # warm up
      control = ActiveRecord::QueryRecorder.new { post_graphql(trigger_query, current_user: user) }

      create_post_processing_profile('second profile')
      create_post_processing_profile('third profile')

      expect { post_graphql(trigger_query, current_user: user) }.not_to exceed_query_limit(control)
    end
  end
end
