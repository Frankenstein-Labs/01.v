# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::ApplicationSetting, :with_current_organization, feature_category: :shared do # rubocop:disable RSpec/FeatureCategory -- Application Settings are shared, describe block provide proper category.
  let_it_be(:default_organization) { create(:organization, :default) } # rubocop:disable Gitlab/RSpec/AvoidCreateDefaultOrganization -- instance AI settings are stored on the default organization
  let_it_be_with_reload(:application_setting) { create(:application_setting) }

  before do
    allow(::Organizations::Organization).to receive(:default_organization).and_return(default_organization)
  end

  subject(:output) { described_class.new(application_setting).as_json }

  shared_examples 'licensed feature exposing application settings' do |licensed_feature, settings|
    context "when #{licensed_feature} feature is enabled" do
      before do
        stub_licensed_features(licensed_feature => true)
      end

      it "exposes the #{licensed_feature} settings", :aggregate_failures do
        settings.each do |setting|
          expect(subject[setting]).to eq(application_setting.public_send(setting))
        end
      end
    end

    context "when #{licensed_feature} feature is disabled" do
      before do
        stub_licensed_features(licensed_feature => false)
      end

      it "does not expose the #{licensed_feature} settings", :aggregate_failures do
        settings.each do |setting|
          expect(subject[setting]).to be_nil
        end
      end
    end
  end

  describe 'dependency scanning settings', feature_category: :software_composition_analysis do
    it_behaves_like 'licensed feature exposing application settings', :dependency_scanning, %i[
      dependency_scanning_sbom_scan_api_download_limit
      dependency_scanning_sbom_scan_api_upload_limit
    ]
  end

  describe 'duo workflows settings', feature_category: :ai_abstraction_layer do
    it_behaves_like 'licensed feature exposing application settings', :ai_features, %i[
      duo_workflows_default_image_registry
    ]
  end

  describe 'duo CLI setting', feature_category: :ai_abstraction_layer do
    before do
      stub_licensed_features(ai_features: true)
    end

    it 'exposes the current value from Ai::Setting' do
      ::Ai::Setting.for_organization(current_organization).update!(duo_cli_enabled: false)

      expect(output[:duo_cli_enabled]).to be(false)
    end

    it 'defaults to true on a fresh instance' do
      expect(output[:duo_cli_enabled]).to be(true)
    end
  end

  describe 'AI audit events streaming setting', feature_category: :audit_events do
    before do
      stub_licensed_features(ai_features: true)
    end

    it 'exposes the current value from Ai::Setting' do
      ::Ai::Setting.for_organization(current_organization).update!(ai_audit_events_streaming_enabled: true)

      expect(output[:ai_audit_events_streaming_enabled]).to be(true)
    end

    it 'defaults to false on a fresh instance' do
      expect(output[:ai_audit_events_streaming_enabled]).to be(false)
    end
  end

  describe 'duo_template_project_id setting', feature_category: :duo_code_review do
    using RSpec::Parameterized::TableSyntax

    where(:duo_template_project_available, :duo_template_project_id) do
      true  | 42
      false | nil
    end

    with_them do
      before do
        allow(application_setting).to receive_messages(
          duo_template_project_id: 42,
          duo_template_project_available?: duo_template_project_available
        )
      end

      it { expect(output[:duo_template_project_id]).to eq(duo_template_project_id) }
    end
  end

  describe 'ci telemetry settings', feature_category: :fleet_visibility do
    it 'exposes ci_telemetry_otel_endpoint' do
      expect(output[:ci_telemetry_otel_endpoint]).to eq(application_setting.ci_telemetry_otel_endpoint)
    end

    it 'exposes ci_job_telemetry_sampling_rate' do
      expect(output[:ci_job_telemetry_sampling_rate]).to eq(application_setting.ci_job_telemetry_sampling_rate)
    end

    context 'when ci_job_telemetry_settings feature flag is disabled' do
      before do
        stub_feature_flags(ci_job_telemetry_settings: false)
      end

      it 'does not expose ci_telemetry_otel_endpoint' do
        expect(output).not_to have_key(:ci_telemetry_otel_endpoint)
      end

      it 'does not expose ci_job_telemetry_sampling_rate' do
        expect(output).not_to have_key(:ci_job_telemetry_sampling_rate)
      end
    end
  end
end
