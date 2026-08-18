# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notifications::TargetedMessages::DestroyWorker, feature_category: :acquisition do
  let_it_be(:targeted_message) { create(:targeted_message) }

  describe '#perform' do
    it 'destroys the targeted message' do
      expect { described_class.new.perform(targeted_message.id) }
        .to change { Notifications::TargetedMessage.count }.by(-1)
    end

    context 'when targeted message does not exist' do
      it 'logs it and does not raise an error' do
        expect(Gitlab::AppLogger).to receive(:info).with("TargetedMessage with ID #{non_existing_record_id} not found.")

        expect { described_class.new.perform(non_existing_record_id) }.not_to raise_error
      end
    end

    context 'with associated records' do
      let_it_be(:namespaces) { create_list(:namespace, 5) }
      let_it_be(:targeted_message_namespaces) do
        namespaces.map { |ns| create(:targeted_message_namespace, targeted_message: targeted_message, namespace: ns) }
      end

      let_it_be(:dismissals) do
        targeted_message_namespaces.flat_map do |tmn|
          create_list(:targeted_message_dismissal, 3,
            targeted_message: targeted_message,
            namespace: tmn.namespace)
        end
      end

      it 'deletes all associated records' do
        expect { described_class.new.perform(targeted_message.id) }
          .to change { Notifications::TargetedMessageDismissal.count }.by(-15)
          .and change { Notifications::TargetedMessageNamespace.count }.by(-6)
          .and change { Notifications::TargetedMessage.count }.by(-1)
      end
    end
  end
end
