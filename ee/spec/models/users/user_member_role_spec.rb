# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::UserMemberRole, feature_category: :system_access do
  describe 'associations' do
    it { is_expected.to belong_to(:member_role) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validation' do
    subject(:user_member_role) { build(:user_member_role) }

    it { is_expected.to validate_presence_of(:member_role) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_uniqueness_of(:user) }
  end

  describe '.ldap_synced' do
    let_it_be(:user_member_role) { create(:user_member_role) }
    let_it_be(:user_member_role_ldap) { create(:user_member_role, ldap: true) }

    subject(:ldap_synced_user_roles) do
      described_class.ldap_synced
    end

    it 'returns only records with ldap true' do
      expect(ldap_synced_user_roles).to eq([user_member_role_ldap])
    end
  end

  describe '.with_identity_provider' do
    let_it_be(:provider) { 'ldapmain' }

    let_it_be(:user) { create(:user) }
    let_it_be(:user_member_role) { create(:user_member_role, user: user) }

    subject(:with_identity_provider) { described_class.with_identity_provider(provider) }

    context 'when the user has an identity for the provider' do
      before do
        create(:identity, user: user, provider: provider)
      end

      it 'returns the record' do
        expect(with_identity_provider).to eq([user_member_role])
      end
    end

    context 'when the user has an identity for a different provider' do
      before do
        create(:identity, user: user, provider: 'jwt', extern_uid: 'jwt-uid')
      end

      it 'returns an empty array' do
        expect(with_identity_provider).to eq([])
      end
    end
  end

  describe '.preload_user' do
    let_it_be(:user_member_role) { create(:user_member_role) }

    subject(:relation) { described_class.preload_user }

    it 'loads user association' do
      expect(relation.first.association(:user)).to be_loaded
    end
  end
end
