# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::InstanceExternalAuditEventDestination, feature_category: :audit_events do
  subject(:destination) { build(:instance_external_audit_event_destination) }

  it_behaves_like 'includes CustomHttpExternallyDestinationable concern' do
    subject(:destination_without_verification_token) do
      create(:instance_external_audit_event_destination, verification_token: nil)
    end

    let_it_be(:audit_event) { create(:audit_event, :instance_event) }
    let_it_be(:audit_operation) { 'event_type_filters_created' }
    let_it_be(:destination_with_filters_of_given_type) { create(:instance_external_audit_event_destination) }
    let_it_be(:filter1) do
      create(:audit_events_streaming_instance_event_type_filter,
        instance_external_audit_event_destination: destination_with_filters_of_given_type,
        audit_event_type: 'event_type_filters_created')
    end

    let_it_be(:filter2) do
      create(:audit_events_streaming_instance_event_type_filter,
        instance_external_audit_event_destination: destination_with_filters_of_given_type,
        audit_event_type: 'event_type_filters_deleted')
    end

    let_it_be(:destination_with_filters) { create(:instance_external_audit_event_destination) }
    let!(:filter3) do
      create(:audit_events_streaming_instance_event_type_filter,
        instance_external_audit_event_destination: destination_with_filters,
        audit_event_type: 'event_type_filters_deleted')
    end
  end

  it_behaves_like 'includes Limitable concern'

  it_behaves_like 'includes ExternallyCommonDestinationable concern' do
    let(:model_factory_name) { :instance_external_audit_event_destination }
  end

  it_behaves_like 'includes InstanceStreamDestinationMappable concern',
    let(:model_factory_name) { :instance_external_audit_event_destination }

  it_behaves_like 'includes Activatable concern' do
    let(:model_factory_name) { :instance_external_audit_event_destination }
  end

  describe 'Associations' do
    it { is_expected.to have_one(:namespace_filter) }
  end

  describe 'Validations' do
    it { is_expected.to have_many(:headers).class_name('AuditEvents::Streaming::InstanceHeader') }
    it { is_expected.to have_many(:event_type_filters).class_name('AuditEvents::Streaming::InstanceEventTypeFilter') }

    context 'with headers limit' do
      before do
        stub_const('AuditEvents::CustomHttpExternallyDestinationable::MAXIMUM_HEADER_COUNT', 3)
        create_list(:instance_audit_events_streaming_header, 3, instance_external_audit_event_destination: subject)
      end

      it 'can have the maximum number of headers' do
        expect(subject).to be_valid
      end

      it 'can have no more than the maximum number of headers' do
        create(:instance_audit_events_streaming_header, instance_external_audit_event_destination: subject)

        expect(subject).not_to be_valid
        expect(subject.errors.full_messages).to contain_exactly('Headers are limited to 3 per destination')
      end
    end

    it 'validates uniqueness of destination_url' do
      create(:instance_external_audit_event_destination, destination_url: 'https://www.example.com')
      destination = build(:instance_external_audit_event_destination, destination_url: 'https://www.example.com')

      expect(destination).not_to be_valid
      expect(destination.errors.full_messages).to include('Destination url has already been taken')
    end

    it 'validates uniqueness of name' do
      create(:instance_external_audit_event_destination, name: 'Test Destination')
      destination = build(:instance_external_audit_event_destination, name: 'Test Destination')

      expect(destination).not_to be_valid
      expect(destination.errors.full_messages).to include('Name has already been taken')
    end
  end

  describe '#headers_hash' do
    subject { destination.headers_hash }

    context "when destination has 2 headers" do
      before do
        create(:instance_audit_events_streaming_header, instance_external_audit_event_destination: destination,
          key: 'X-GitLab-Hello')
        create(:instance_audit_events_streaming_header, instance_external_audit_event_destination: destination,
          key: 'X-GitLab-World')
        create(:instance_audit_events_streaming_header, instance_external_audit_event_destination: destination,
          key: 'X-GitLab-Inactive', active: false)
      end

      it 'return active headers' do
        is_expected.to eq({ 'X-GitLab-Hello' => 'bar',
                            'X-GitLab-World' => 'bar',
                            'X-Gitlab-Event-Streaming-Token' => destination.verification_token })
      end
    end

    it 'must have a unique destination_url', :aggregate_failures do
      create(:instance_external_audit_event_destination, destination_url: 'https://example.com/1')
      dup = build(:instance_external_audit_event_destination, destination_url: 'https://example.com/1')

      expect(dup).to be_invalid
      expect(dup.errors.full_messages).to include('Destination url has already been taken')
    end
  end
end
