# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Instance::GoogleCloudLoggingConfiguration, feature_category: :audit_events do
  subject(:instance_google_cloud_logging_config) { build(:instance_google_cloud_logging_configuration) }

  describe 'Validations' do
    context 'when the same google_project_id_name for the same log_id_name exists' do
      let(:google_project_id_name) { 'valid-project-id' }
      let(:log_id_name) { 'audit_events' }

      before do
        create(:instance_google_cloud_logging_configuration, google_project_id_name: google_project_id_name,
          log_id_name: log_id_name)
      end

      it 'is not valid and adds an error message' do
        config = build(:instance_google_cloud_logging_configuration, google_project_id_name: google_project_id_name,
          log_id_name: log_id_name)
        expect(config).not_to be_valid
        expect(config.errors[:log_id_name]).to include('has already been taken')
      end
    end

    it 'validates uniqueness of name' do
      create(:instance_google_cloud_logging_configuration, name: 'Test Destination')
      destination = build(:instance_google_cloud_logging_configuration, name: 'Test Destination')

      expect(destination).not_to be_valid
      expect(destination.errors.full_messages).to include('Name has already been taken')
    end
  end

  it_behaves_like 'includes GcpExternallyDestinationable concern'

  it_behaves_like 'includes Limitable concern'

  it_behaves_like 'includes ExternallyCommonDestinationable concern' do
    let(:model_factory_name) { :instance_google_cloud_logging_configuration }
  end

  it_behaves_like 'includes InstanceStreamDestinationMappable concern',
    let(:model_factory_name) { :instance_google_cloud_logging_configuration }

  it_behaves_like 'includes Activatable concern' do
    let(:model_factory_name) { :instance_google_cloud_logging_configuration }
  end
end
