# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemAccess::GroupMicrosoftGraphAccessToken, type: :model, feature_category: :system_access do
  let(:application) { create(:system_access_group_microsoft_application) }
  let(:token) do
    create(:system_access_group_microsoft_graph_access_token, system_access_group_microsoft_application: application)
  end

  describe 'associations' do
    it 'belongs to a MicrosoftApplication' do
      is_expected.to belong_to(:system_access_group_microsoft_application)
        .class_name('SystemAccess::GroupMicrosoftApplication')
        .inverse_of(:graph_access_token)
    end

    it 'has legacy association for MicrosoftApplication' do
      is_expected.to belong_to(:system_access_microsoft_application)
        .class_name('SystemAccess::GroupMicrosoftApplication')
        .inverse_of(:graph_access_token)
    end
  end

  it_behaves_like 'encrypted attribute', :token, :db_key_base_32 do
    let(:record) { token }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:system_access_group_microsoft_application_id) }
    it { is_expected.to validate_presence_of(:expires_in) }
    it { is_expected.to validate_numericality_of(:expires_in).is_greater_than_or_equal_to(0) }
  end

  describe 'encrypted attributes' do
    it 'encrypts the token attribute' do
      token.update!(token: 'test_token')
      expect(token.encrypted_token).not_to eq('test_token')
      expect(token.token).to eq('test_token')
    end
  end

  describe '#expired?' do
    context 'when the token is not persisted' do
      it 'returns true' do
        new_token = described_class.new(expires_in: 3600)
        expect(new_token.expired?).to be true
      end
    end

    context 'when the token is expired' do
      it 'returns true' do
        token.update!(updated_at: 2.hours.ago, expires_in: 3600)
        expect(token.expired?).to be true
      end
    end

    context 'when the token is not expired' do
      it 'returns false' do
        token.update!(updated_at: Time.zone.now, expires_in: 3600)
        expect(token.expired?).to be false
      end
    end
  end
end
