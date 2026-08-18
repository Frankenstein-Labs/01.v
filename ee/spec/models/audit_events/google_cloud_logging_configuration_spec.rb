# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::GoogleCloudLoggingConfiguration, feature_category: :audit_events do
  subject(:google_cloud_logging_config) { build(:google_cloud_logging_configuration) }

  describe 'Associations' do
    it 'belongs to a group' do
      expect(google_cloud_logging_config.group).to be_kind_of(Group)
    end
  end

  describe 'Validations' do
    let_it_be(:group) { create(:group) }

    context 'when the same google_project_id_name for the same namespace and log_id_name exists' do
      let(:google_project_id_name) { 'valid-project-id' }
      let(:log_id_name) { 'audit_events' }

      before do
        create(:google_cloud_logging_configuration, group: group, google_project_id_name: google_project_id_name,
          log_id_name: log_id_name)
      end

      it 'is not valid and adds an error message' do
        config = build(:google_cloud_logging_configuration, group: group,
          google_project_id_name: google_project_id_name, log_id_name: log_id_name)
        expect(config).not_to be_valid
        expect(config.errors[:google_project_id_name]).to include('has already been taken')
      end
    end

    context 'when the group is a subgroup' do
      let_it_be(:subgroup) { create(:group, parent: group) }

      before do
        google_cloud_logging_config.group = subgroup
      end

      it 'is not valid and adds an error message' do
        expect(google_cloud_logging_config).not_to be_valid
        expect(google_cloud_logging_config.errors[:group]).to include('must not be a subgroup')
      end
    end

    it 'validates uniqueness of name scoped to namespace' do
      create(:google_cloud_logging_configuration, name: 'Test Destination', group: group)
      destination = build(:google_cloud_logging_configuration, name: 'Test Destination', group: group)

      expect(destination).not_to be_valid
      expect(destination.errors.full_messages).to include('Name has already been taken')
    end
  end

  it_behaves_like 'includes GcpExternallyDestinationable concern'

  it_behaves_like 'includes Limitable concern' do
    subject { build(:google_cloud_logging_configuration, group: create(:group)) }
  end

  it_behaves_like 'includes ExternallyCommonDestinationable concern' do
    let(:model_factory_name) { :google_cloud_logging_configuration }
  end

  it_behaves_like 'includes GroupStreamDestinationMappable concern',
    let(:model_factory_name) { :google_cloud_logging_configuration }

  it_behaves_like 'includes Activatable concern' do
    let(:model_factory_name) { :google_cloud_logging_configuration }
  end
end
