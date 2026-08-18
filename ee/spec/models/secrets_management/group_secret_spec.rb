# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecret, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }

  subject(:secret) do
    described_class.new(
      group: group,
      name: 'TEST_SECRET',
      environment: 'production',
      protected: true,
      create_started_at: Time.now.iso8601.to_s,
      create_completed_at: Time.now.iso8601.to_s
    )
  end

  it_behaves_like 'a secret model'

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:environment) }

    describe 'protected validation' do
      it 'allows true' do
        secret.protected = true
        expect(secret).to be_valid
      end

      it 'allows false' do
        secret.protected = false
        expect(secret).to be_valid
      end

      it 'rejects nil' do
        secret.protected = nil
        expect(secret).not_to be_valid
        expect(secret.errors[:protected]).to include('is not included in the list')
      end
    end
  end

  describe 'attributes' do
    it 'has expected attributes specific to group secrets' do
      expect(secret).to have_attributes(
        environment: 'production',
        protected: true,
        group: group
      )
    end

    it 'defaults protected to false' do
      secret = described_class.new(group: group, name: 'TEST', environment: 'prod')
      expect(secret.protected).to be false
    end
  end

  describe 'dirty tracking' do
    it 'tracks changes to protected' do
      expect(secret.protected_changed?).to be_falsey

      secret.protected = false
      expect(secret.protected_changed?).to be_truthy
      expect(secret.protected_was).to be true
    end
  end
end
