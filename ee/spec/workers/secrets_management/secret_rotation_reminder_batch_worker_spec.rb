# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretRotationReminderBatchWorker, feature_category: :secrets_management do
  it_behaves_like 'an idempotent worker'

  describe '#perform' do
    it 'does nothing' do
      expect { described_class.new.perform }.not_to raise_error
    end
  end
end
