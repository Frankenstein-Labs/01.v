# frozen_string_literal: true

RSpec.shared_examples 'includes InstanceStreamDestinationMappable concern' do
  describe 'validations' do
    it { is_expected.to be_a(AuditEvents::InstanceStreamDestinationMappable) }

    context 'when associated' do
      it 'validates the model' do
        destination = build(model_factory_name)
        expect(destination).to belong_to(:stream_destination)
        .class_name('AuditEvents::Instance::ExternalStreamingDestination')
        .optional

        expect(destination.instance_level?).to be_truthy
      end
    end
  end
end
