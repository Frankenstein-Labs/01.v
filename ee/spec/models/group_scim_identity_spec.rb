# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupScimIdentity, type: :model, feature_category: :user_management do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    subject { create(:group_scim_identity) }

    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:extern_uid) }

    it 'validates uniqueness of user scoped to group' do
      group = create(:group)
      user = create(:user)
      create(:group_scim_identity, group: group, user: user)

      duplicate_identity = build(:group_scim_identity, group: group, user: user)
      expect(duplicate_identity).not_to be_valid
      expect(duplicate_identity.errors[:user]).to include('has already been taken')
    end

    it 'validates uniqueness of extern_uid scoped to group, case insensitive' do
      group = create(:group)
      create(:group_scim_identity, group: group, extern_uid: 'UID123')

      duplicate_uid_identity = build(:group_scim_identity, group: group, extern_uid: 'uid123')
      expect(duplicate_uid_identity).not_to be_valid
      expect(duplicate_uid_identity.errors[:extern_uid]).to include('has already been taken')
    end
  end

  describe 'scopes' do
    describe '.for_user' do
      it 'returns scim identities for the specified user' do
        user = create(:user)
        group_identity = create(:group_scim_identity, user: user)
        create(:group_scim_identity) # unrelated identity

        expect(described_class.for_user(user)).to contain_exactly(group_identity)
      end
    end

    describe '.with_extern_uid' do
      it 'returns scim identities with the specified extern_uid, case insensitive' do
        group_identity = create(:group_scim_identity, extern_uid: 'EXT123')
        create(:group_scim_identity, extern_uid: 'OTHER123') # unrelated identity

        expect(described_class.with_extern_uid('ext123')).to contain_exactly(group_identity)
      end
    end
  end
end
