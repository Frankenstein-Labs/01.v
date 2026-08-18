# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleLinks::CreateService, :enable_admin_mode, feature_category: :permissions do
  describe '#execute' do
    let_it_be(:organization) { create(:common_organization) }
    let_it_be(:admin_member_role) { create(:member_role, :admin, name: 'Admin role') }
    let_it_be(:user) { create(:admin) }

    let_it_be(:default_params) do
      {
        provider: 'ldap',
        cn: 'cn',
        organization_id: organization.id,
        member_role: admin_member_role
      }
    end

    let(:params) { default_params }

    before do
      allow(::Gitlab::Auth::Ldap::Config).to receive_messages(providers: ['ldap'])
    end

    subject(:create_admin_link) { described_class.new(user, params).execute }

    context 'without the custom roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'returns an error' do
        expect(create_admin_link).to have_attributes(
          success?: false,
          message: 'custom_roles licensed feature must be available'
        )
      end
    end

    context 'with the custom roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'creates a link' do
        expect { create_admin_link }.to change { Authz::LdapAdminRoleLink.count }.by(1)
      end

      it 'returns success' do
        expect(create_admin_link).to have_attributes(
          success?: true,
          payload: { ldap_admin_role_link: ::Authz::LdapAdminRoleLink.last }
        )
      end

      context 'when member role provided is not an admin role' do
        let_it_be(:member_role) { create(:member_role, name: 'Standard role') }

        let(:params) { default_params.merge(member_role: member_role) }

        it 'returns an error' do
          expect(create_admin_link).to have_attributes(
            success?: false,
            message: 'Only admin custom roles can be assigned'
          )
        end
      end

      context 'when current user is not an admin' do
        let_it_be(:user) { create(:user) }

        it 'returns an error' do
          expect(create_admin_link).to have_attributes(
            success?: false,
            message: 'Unauthorized'
          )
        end
      end

      context 'when there is a missing param' do
        let(:params) { default_params.except(:provider) }

        it 'returns an error' do
          expect(create_admin_link).to have_attributes(
            success?: false,
            message: "Provider can't be blank"
          )
        end
      end
    end
  end
end
