# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::GroupSamlUsersFinder, feature_category: :system_access do
  describe '#execute' do
    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:saml_provider) { create(:saml_provider, group: group) }

    let_it_be(:subgroup) { create(:group, parent: group) }

    let_it_be(:maintainer_of_the_group) { create(:user, maintainer_of: group) }
    let_it_be(:owner_of_the_group) { create(:user, owner_of: group) }

    let_it_be(:non_saml_user) { create(:user) }
    let_it_be(:saml_user_of_another_group) { create(:group_saml_identity).user }
    let_it_be(:non_saml_user_with_identity) { create(:omniauth_user, provider: 'google') }

    let_it_be(:saml_user_of_the_group) { create(:group_saml_identity, saml_provider: saml_provider).user }

    let_it_be(:blocked_saml_user_of_the_group) do
      create(:group_saml_identity, saml_provider: saml_provider, user: create(:user, :blocked)).user
    end

    let(:current_user) { owner_of_the_group }

    let(:params) { { group: group } }

    subject(:finder) { described_class.new(current_user, params).execute }

    context 'when group parameter is not passed' do
      let(:params) { {} }

      it 'raises error that group is required' do
        expect { finder }.to raise_error(ArgumentError, 'Group is required for GroupSamlUsersFinder')
      end
    end

    context 'when group parameter is not top-level group' do
      let(:params) { { group: subgroup } }

      it 'raises error that group must be a top-level group' do
        expect { finder }.to raise_error(ArgumentError, 'Group must be a top-level group')
      end
    end

    context 'when current_user is not owner of the group' do
      let(:current_user) { maintainer_of_the_group }

      it 'raises Gitlab::Access::AccessDeniedError' do
        expect { finder }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    it 'returns SAML users of the group in descending order by id' do
      users = finder

      expect(users).to eq(
        [
          saml_user_of_the_group,
          blocked_saml_user_of_the_group
        ].sort_by(&:id).reverse
      )
    end

    context 'when group does not have saml_provider' do
      before_all do
        saml_provider.destroy!
      end

      it 'does not return any users' do
        users = finder

        expect(users).to eq([])
      end
    end

    context 'for search parameter' do
      context 'for search by name' do
        let(:params) { { group: group, search: saml_user_of_the_group.name } }

        it 'returns SAML users of the group according to the search parameter' do
          users = finder

          expect(users).to eq(
            [
              saml_user_of_the_group
            ]
          )
        end
      end

      context 'for search by username' do
        let(:params) { { group: group, search: blocked_saml_user_of_the_group.username } }

        it 'returns SAML users of the group according to the search parameter' do
          users = finder

          expect(users).to eq(
            [
              blocked_saml_user_of_the_group
            ]
          )
        end
      end

      context 'for search by public email' do
        let_it_be(:saml_user_of_the_group_with_public_email) do
          create(:group_saml_identity, saml_provider: saml_provider, user: create(:user, :public_email)).user
        end

        let(:params) do
          { group: group, search: saml_user_of_the_group_with_public_email.public_email }
        end

        it 'returns SAML users of the group according to the search parameter', :aggregate_failures do
          expect(saml_user_of_the_group_with_public_email.public_email).to be_present

          users = finder

          expect(users).to eq(
            [
              saml_user_of_the_group_with_public_email
            ]
          )
        end
      end

      context 'for search by private email' do
        let_it_be(:saml_user_of_the_group_without_public_email) do
          create(:group_saml_identity, saml_provider: saml_provider, user: create(:user)).user
        end

        let(:params) do
          { group: group, search: saml_user_of_the_group_without_public_email.email }
        end

        it 'returns SAML users of the group according to the search parameter', :aggregate_failures do
          expect(saml_user_of_the_group_without_public_email.public_email).not_to be_present

          users = finder

          expect(users).to eq(
            [
              saml_user_of_the_group_without_public_email
            ]
          )
        end
      end
    end
  end
end
