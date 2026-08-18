# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::EmitSecretsStoredBillableEventWorker, feature_category: :secrets_management do
  let_it_be(:root_namespace) { create(:group) }

  describe '#perform' do
    it 'delegates to the SecretsStoredEmitter for the given root namespace id' do
      expect(SecretsManagement::BillableEvents::SecretsStoredEmitter)
        .to receive(:emit_for_root_namespace_id!).with(root_namespace.id)

      described_class.new.perform(root_namespace.id)
    end
  end

  describe '.idempotency_arguments' do
    it 'returns only the root_namespace_id, ignoring trailing arguments' do
      expect(described_class.idempotency_arguments([42, 'ignored'])).to eq([42])
    end
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [root_namespace.id] }

    before do
      allow(SecretsManagement::BillableEvents::SecretsStoredEmitter).to receive(:emit_for_root_namespace_id!)
    end
  end
end
