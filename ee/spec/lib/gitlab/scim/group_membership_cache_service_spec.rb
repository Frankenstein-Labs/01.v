# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Scim::GroupMembershipCacheService, feature_category: :system_access do
  let(:scim_group_uid) { SecureRandom.uuid }

  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:user3) { create(:user) }

  let(:service) { described_class.new(scim_group_uid: scim_group_uid) }

  describe '#add_users' do
    it 'adds users to the SCIM group cache' do
      expect { service.add_users([user1.id, user2.id]) }.to change { Authn::ScimGroupMembership.count }.by(2)

      expect(Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).map(&:user_id))
        .to match_array([user1.id, user2.id])
    end

    it 'does nothing if users is empty' do
      expect { service.add_users([]) }.not_to change { Authn::ScimGroupMembership.count }
    end
  end

  describe '#remove_users' do
    before do
      create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid)
      create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid)
      create(:scim_group_membership, user: user3, scim_group_uid: scim_group_uid)
    end

    it 'removes specified users from the SCIM group cache' do
      expect { service.remove_users([user1.id, user2.id]) }.to change { Authn::ScimGroupMembership.count }.by(-2)

      remaining_user_ids = Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).map(&:user_id)
      expect(remaining_user_ids).to eq([user3.id])
    end

    it 'does nothing if users is empty' do
      expect { service.remove_users([]) }.not_to change { Authn::ScimGroupMembership.count }
    end
  end

  describe '#replace_users' do
    before do
      create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid)
      create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid)
    end

    it 'replaces all users in the SCIM group cache' do
      service.replace_users([user2.id, user3.id])

      user_ids = Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).map(&:user_id)
      expect(user_ids).to match_array([user2.id, user3.id])
    end

    it 'clears cache when replacing with empty list' do
      expect { service.replace_users([]) }
        .to change { Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).count }.to(0)
    end
  end
end
