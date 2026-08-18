# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ProjectSettingsDestroyWorker, feature_category: :compliance_management do
  let_it_be(:framework_id) { 12345 }
  let_it_be(:namespace_id) { 98765 }

  subject(:worker) { described_class.new }

  it 'includes ApplicationWorker' do
    expect(described_class).to include(ApplicationWorker)
  end

  it 'is configured with the correct attributes' do
    expect(described_class.get_feature_category).to eq(:compliance_management)
    expect(described_class.get_urgency).to eq(:low)
  end

  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    it 'calls the ProjectSettingsDestroyService with framework_ids' do
      expect_next_instance_of(ComplianceManagement::Frameworks::ProjectSettingsDestroyService,
        framework_ids: framework_id, namespace_id: nil) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      worker.perform(nil, framework_id)
    end

    it 'calls the ProjectSettingsDestroyService with namespace_id' do
      expect_next_instance_of(ComplianceManagement::Frameworks::ProjectSettingsDestroyService,
        framework_ids: nil, namespace_id: namespace_id) do |service|
        expect(service).to receive(:execute).and_call_original
      end

      worker.perform(namespace_id, nil)
    end

    context 'when passing nil params' do
      it 'calls the ProjectSettingsDestroyService with nil' do
        expect(ComplianceManagement::Frameworks::ProjectSettingsDestroyService).not_to receive(:new)

        worker.perform(nil, nil)
      end

      it 'does not raise an error' do
        expect { worker.perform(nil, nil) }.not_to raise_error
      end
    end

    context 'when framework_id is a string' do
      let(:string_framework_id) { '12345' }

      it 'calls the ProjectSettingsDestroyService with the string id' do
        expect_next_instance_of(ComplianceManagement::Frameworks::ProjectSettingsDestroyService,
          framework_ids: string_framework_id, namespace_id: nil) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        worker.perform(nil, string_framework_id)
      end
    end

    context 'when framework_id is an array' do
      let(:framework_ids_array) { [12345, 67890] }

      it 'calls the ProjectSettingsDestroyService with the array' do
        expect_next_instance_of(ComplianceManagement::Frameworks::ProjectSettingsDestroyService,
          framework_ids: framework_ids_array, namespace_id: nil) do |service|
          expect(service).to receive(:execute).and_call_original
        end

        worker.perform(nil, framework_ids_array)
      end
    end
  end

  context 'when the service returns an error response' do
    let(:error_message) { 'Failed to delete project settings for frameworks: Database connection error' }
    let(:error_result) { ServiceResponse.error(message: error_message) }

    before do
      allow_next_instance_of(ComplianceManagement::Frameworks::ProjectSettingsDestroyService) do |service|
        allow(service).to receive(:execute).and_return(error_result)
      end
    end

    it 'tracks the exception with the correct error message' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception) do |exception, context|
        expect(exception.message).to eq(error_message)
        expect(context[:framework_ids]).to eq(framework_id)
        expect(context[:worker]).to eq('ComplianceManagement::ProjectSettingsDestroyWorker')
      end

      worker.perform(nil, framework_id)
    end

    it 'returns the error result' do
      allow(Gitlab::ErrorTracking).to receive(:track_exception)

      result = worker.perform(nil, framework_id)
      expect(result).to eq(error_result)
      expect(result).to be_error
    end
  end
end
