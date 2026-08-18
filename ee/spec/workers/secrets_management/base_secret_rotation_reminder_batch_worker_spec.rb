# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::BaseSecretRotationReminderBatchWorker, feature_category: :secrets_management do
  describe '#service_class' do
    it 'raises Gitlab::AbstractMethodError' do
      worker = described_class.new

      expect { worker.send(:service_class) }.to raise_error(Gitlab::AbstractMethodError)
    end
  end
end
