# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::GroupScimFinder, feature_category: :user_management do
  let_it_be(:group) { create(:group) }

  subject(:finder) { described_class.new(group) }

  describe '#search' do
    context 'when SAML is disabled' do
      before do
        create(:saml_provider, group: group, enabled: false)
      end

      it 'returns no SCIM identities' do
        expect(finder.search({})).to eq(GroupScimIdentity.none)
      end
    end

    context 'when SAML is enabled' do
      let_it_be(:saml_provider) { create(:saml_provider, group: group) }
      let_it_be(:user) { create(:user, username: 'johndoe', email: 'johndoe@example.com') }
      let_it_be(:scim_identity) { create(:group_scim_identity, group: group, user: user) }

      context 'when unfiltered' do
        it 'returns all SCIM identities for the group' do
          expect(finder.search({})).to eq([scim_identity])
        end
      end

      context 'with filter on extern_uid' do
        it 'filters identities by extern_uid' do
          result = finder.search(filter: "externalId eq \"#{scim_identity.extern_uid}\"")
          expect(result.first).to eq(scim_identity)
        end
      end

      context 'with filter on username' do
        it 'filters identities by username' do
          result = finder.search(filter: "userName eq \"#{user.username}\"")
          expect(result.first).to eq(scim_identity)
        end

        it 'filters identities by email' do
          result = finder.search(filter: "userName eq \"#{user.email}\"")
          expect(result.first).to eq(scim_identity)
        end

        it 'filters identities by username derived from email' do
          email = "#{user.username}@example.com"
          result = finder.search(filter: "userName eq \"#{email}\"")
          expect(result.first).to eq(scim_identity)
        end
      end

      context 'with unsupported filter' do
        it 'raises an UnsupportedFilter error' do
          expect { finder.search(filter: 'invalid_filter') }.to raise_error(Authn::GroupScimFinder::UnsupportedFilter)
        end
      end
    end
  end

  describe '#email?' do
    it 'returns true for a valid email' do
      expect(finder.send(:email?, 'user@example.com')).to be_truthy
    end

    it 'returns false for an invalid email' do
      expect(finder.send(:email?, 'not-an-email')).to be_falsey
    end
  end

  describe '#email_local_part' do
    it 'returns the local part of the email' do
      expect(finder.send(:email_local_part, 'user@example.com')).to eq('user')
    end
  end
end
