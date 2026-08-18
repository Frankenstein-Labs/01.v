# frozen_string_literal: true

RSpec.shared_examples 'includes GroupStreamDestinationMappable concern' do
  describe 'validations' do
    it { is_expected.to be_a(AuditEvents::GroupStreamDestinationMappable) }

    context 'when associated' do
      it 'validates the model' do
        destination = build(model_factory_name)
        expect(destination).to belong_to(:stream_destination)
        .class_name('AuditEvents::Group::ExternalStreamingDestination')
        .optional

        expect(destination.instance_level?).to be(false)
      end
    end
  end
end
