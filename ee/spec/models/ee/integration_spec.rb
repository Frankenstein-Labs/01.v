# frozen_string_literal: true

require 'spec_helper'

# FIXME: feature_category is fixed but this test covers integrations that
# are owned by different groups
RSpec.describe Integration, feature_category: :not_owned do # rubocop:disable RSpec/FeatureCategory -- See above
  describe 'Scopes' do
    describe '.active' do
      let_it_be(:active_integration) { create(:asana_integration, active: true) }
      let_it_be(:inactive_integration) { create(:asana_integration, active: false) }

      subject { described_class.active }

      it { is_expected.to contain_exactly(active_integration) }

      context 'when integration is blocked by allowlist settings' do
        before do
          stub_application_setting(allow_all_integrations: false)
          stub_licensed_features(integrations_allow_list: true)
        end

        it { is_expected.to be_empty }

        context 'when integration is in allowlist' do
          before do
            stub_application_setting(allowed_integrations: [active_integration.to_param])
          end

          it { is_expected.to contain_exactly(active_integration) }
        end

        context 'when license is insufficient' do
          before do
            stub_licensed_features(integrations_allow_list: false)
          end

          it { is_expected.to contain_exactly(active_integration) }
        end
      end
    end
  end

  describe '.integration_names' do
    subject { described_class.integration_names }

    it { is_expected.not_to include('google_cloud_platform_workload_identity_federation') }

    context 'when google workload identity federation integration feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it { is_expected.to include('google_cloud_platform_workload_identity_federation') }
    end

    it 'includes git_guardian in Integration.project_specific_integration_names' do
      expect(described_class.integration_names)
        .to include('git_guardian')
    end
  end

  describe '.project_specific_integration_names' do
    subject { described_class.project_specific_integration_names }

    it { is_expected.not_to include('google_cloud_platform_artifact_registry') }

    context 'when google artifact registry feature is available' do
      before do
        stub_saas_features(google_cloud_support: true)
      end

      it { is_expected.to include(*described_class::EE_PROJECT_LEVEL_ONLY_INTEGRATION_NAMES) }
    end
  end

  describe '.all_integration_names' do
    subject(:names) { described_class.all_integration_names }

    it 'includes integrations that are blocked by allowlist settings' do
      stub_application_setting(allow_all_integrations: false)
      stub_licensed_features(integrations_allow_list: true)

      expect(Integrations::Asana).to be_blocked_by_settings
      expect(names).to include(Integrations::Asana.to_param)
    end
  end

  describe '.blocked_by_settings?' do
    subject(:integration_class) { Integrations::Asana }

    it { is_expected.not_to be_blocked_by_settings }

    it 'does not log when log: true is passed' do
      expect(Gitlab::IntegrationsLogger).not_to receive(:info)

      integration_class.blocked_by_settings?(log: true)
    end

    context 'when application settings do not allow all integrations' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it { is_expected.to be_blocked_by_settings }

      it 'does not log by default' do
        expect(Gitlab::IntegrationsLogger).not_to receive(:info)

        integration_class.blocked_by_settings?
      end

      it 'logs when log: true is passed' do
        expect(Gitlab::IntegrationsLogger)
          .to receive(:info).with(message: "#{integration_class.title} blocked by settings")

        integration_class.blocked_by_settings?(log: true)
      end

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration_class.to_param])
        end

        it { is_expected.not_to be_blocked_by_settings }
      end

      context 'when license is insufficient' do
        before do
          stub_licensed_features(integrations_allow_list: false)
        end

        it { is_expected.not_to be_blocked_by_settings }
      end
    end
  end

  describe '.vulnerability_hooks' do
    it 'includes integrations where vulnerability_events is true' do
      create(:integration, active: true, vulnerability_events: true)

      expect(described_class.vulnerability_hooks.count).to eq 1
    end

    it 'excludes integrations where vulnerability_events is false' do
      create(:integration, active: true, vulnerability_events: false)

      expect(described_class.vulnerability_hooks.count).to eq 0
    end
  end

  describe '.integration_name_to_type' do
    it 'handles a simple case' do
      expect(described_class.integration_name_to_type(:asana)).to eq 'Integrations::Asana'
    end

    it 'raises an error if the name is unknown' do
      expect { described_class.integration_name_to_type('foo') }
        .to raise_exception(described_class::UnknownType, /foo/)
    end

    it 'handles all available_integration_names' do
      types = described_class.available_integration_names.map { |name| described_class.integration_name_to_type(name) }

      expect(types).to all(start_with('Integrations::'))
    end

    context 'with a Google Cloud integration' do
      it 'handles the name' do
        expect(described_class.integration_name_to_type(:google_cloud_platform_artifact_registry))
          .to eq('Integrations::GoogleCloudPlatform::ArtifactRegistry')
      end
    end

    context 'when integration is blocked by allowlist settings' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it 'still returns the type' do
        expect(Integrations::Asana).to be_blocked_by_settings
        expect(described_class.integration_name_to_type(Integrations::Asana.to_param)).to eq('Integrations::Asana')
      end
    end

    context 'with amazon q integration' do
      it 'does not include amazon q integration' do
        expect(described_class.available_integration_names).not_to include('amazon_q')
      end

      context 'when it is enabled' do
        before do
          allow(::Ai::AmazonQ).to receive(:feature_available?).and_return(true)
        end

        it 'includes amazon q integration' do
          expect(described_class.available_integration_names).to include('amazon_q')
        end
      end
    end
  end

  describe '.available_integration_names' do
    let(:integration_name) { ::Integrations::Asana.to_param }

    subject { described_class.available_integration_names }

    it { is_expected.to include(integration_name) }

    context 'when integration is blocked by allowlist settings' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it { is_expected.not_to include(integration_name) }

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration_name])
        end

        it { is_expected.to include(integration_name) }
      end

      context 'when include_blocked_by_settings: true is passed' do
        subject { described_class.available_integration_names(include_blocked_by_settings: true) }

        it { is_expected.to include(integration_name) }
      end

      context 'when license is insufficient' do
        before do
          stub_licensed_features(integrations_allow_list: false)
        end

        it { is_expected.to include(integration_name) }
      end
    end
  end

  describe '#active and #active?' do
    subject(:integration) { build(:asana_integration) }

    it 'is active' do
      expect(integration.active).to be(true)
      expect(integration.active?).to be(true)
    end

    context 'when integration is blocked by allowlist settings' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it 'is not active' do
        expect(integration.active).to be(false)
        expect(integration.active?).to be(false)
      end

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration.to_param])
        end

        it 'is active' do
          expect(integration.active).to be(true)
          expect(integration.active?).to be(true)
        end
      end

      context 'when license is insufficient' do
        before do
          stub_licensed_features(integrations_allow_list: false)
        end

        it 'is active' do
          expect(integration.active).to be(true)
          expect(integration.active?).to be(true)
        end
      end
    end
  end

  describe '#testable?' do
    subject(:integration) { create(:asana_integration) }

    it { is_expected.to be_testable }

    context 'when integration is blocked by allowlist settings' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it { is_expected.not_to be_testable }

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration.to_param])
        end

        it { is_expected.to be_testable }
      end

      context 'when license is insufficient' do
        before do
          stub_licensed_features(integrations_allow_list: false)
        end

        it { is_expected.to be_testable }
      end
    end
  end

  describe '#async_execute' do
    let(:integration) { build(:jenkins_integration, id: 123) }

    subject(:async_execute) { integration.async_execute({ object_kind: 'push' }) }

    it 'queues an Integrations::ExecuteWorker' do
      expect(Integrations::ExecuteWorker).to receive(:perform_async)

      async_execute
    end

    context 'when application settings do not allow all integrations' do
      before do
        stub_application_setting(allow_all_integrations: false)
        stub_licensed_features(integrations_allow_list: true)
      end

      it 'does not queue an Integrations::ExecuteWorker' do
        expect(Integrations::ExecuteWorker).not_to receive(:perform_async)

        async_execute
      end

      context 'when integration is in allowlist' do
        before do
          stub_application_setting(allowed_integrations: [integration.to_param])
        end

        it 'queues an Integrations::ExecuteWorker' do
          expect(Integrations::ExecuteWorker).to receive(:perform_async)

          async_execute
        end
      end

      context 'when license is insufficient' do
        before do
          stub_licensed_features(integrations_allow_list: false)
        end

        it 'queues an Integrations::ExecuteWorker' do
          expect(Integrations::ExecuteWorker).to receive(:perform_async)

          async_execute
        end
      end
    end
  end

  describe '#blocked_by_settings' do
    let(:integration_class) { Integrations::Asana }

    it 'delegates to the same method on the class' do
      expect(integration_class).to receive(:blocked_by_settings?)

      integration_class.new.blocked_by_settings?
    end
  end

  describe '.instance_specific_integration_types' do
    subject { described_class.instance_specific_integration_types }

    it { is_expected.to eq(['Integrations::AmazonQ', 'Integrations::BeyondIdentity']) }
  end
end
