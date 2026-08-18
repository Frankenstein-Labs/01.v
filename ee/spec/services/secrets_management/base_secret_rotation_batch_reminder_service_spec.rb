# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::BaseSecretRotationBatchReminderService, feature_category: :secrets_management do
  let(:dummy_class) { Class.new(described_class) }
  let(:service) { dummy_class.new }

  describe '#rotation_info_class' do
    it 'raises Gitlab::AbstractMethodError' do
      expect { service.send(:rotation_info_class) }.to raise_error(Gitlab::AbstractMethodError)
    end
  end

  describe '#send_rotation_reminder' do
    it 'raises Gitlab::AbstractMethodError' do
      expect { service.send(:send_rotation_reminder, nil) }.to raise_error(Gitlab::AbstractMethodError)
    end
  end
end
