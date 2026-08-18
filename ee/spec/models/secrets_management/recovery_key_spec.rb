# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::RecoveryKey, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:secret_value) { "secret_value" }
  let(:active) { true }

  describe "validations" do
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_inclusion_of(:active).in_array([true, false]) }
  end

  describe 'default attributes' do
    subject(:recovery_key) { create(:sm_recovery_key, key: secret_value, active: active) }

    it 'has the values specified by the factory' do
      expect(recovery_key.key).to eq(secret_value)
      expect(recovery_key.active).to eq(active)
    end
  end

  describe '#no_other_active' do
    context 'when no recovery keys exist' do
      it 'persists the object' do
        recovery_key = described_class.new do |rk|
          rk.active = true
          rk.key = "new secret_value"
        end

        recovery_key.save!

        expect(recovery_key).to be_persisted
      end
    end

    context 'when only inactive recovery keys exist' do
      let!(:recovery_key) { create(:sm_recovery_key, key: secret_value, active: false) }

      it 'persists the object' do
        recovery_key = described_class.new do |rk|
          rk.active = true
          rk.key = "new secret_value"
        end

        recovery_key.save!

        expect(recovery_key).to be_persisted
      end
    end

    context 'when active recovery keys exist' do
      let!(:recovery_key) { create(:sm_recovery_key, key: secret_value, active: true) }

      it 'persists the object' do
        recovery_key = described_class.new do |rk|
          rk.active = true
          rk.key = "new secret_value"
        end

        expect(recovery_key.save).to be(false)

        expect(recovery_key).not_to be_persisted
        expect(recovery_key).not_to be_valid
        expect(recovery_key.errors.full_messages).to include("A maximum of one active RecoveryKey can exist at a time")
      end
    end

    context 'when updating the existing active key' do
      let!(:recovery_key) { create(:sm_recovery_key, key: secret_value, active: true) }
      let(:new_value) { "new value" }

      it 'persists the object' do
        recovery_key.key = new_value
        recovery_key.save!

        recovery_key.reload

        expect(recovery_key.key).to eq(new_value)
      end
    end
  end
end
