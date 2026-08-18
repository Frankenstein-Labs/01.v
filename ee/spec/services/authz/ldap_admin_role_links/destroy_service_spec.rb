# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::LdapAdminRoleLinks::DestroyService, :enable_admin_mode, feature_category: :permissions do
  describe '#execute' do
    let_it_be(:ldap_admin_role_link) { create(:ldap_admin_role_link, :skip_validate) }
    let_it_be(:user) { create(:admin) }

    let(:params) { { id: ldap_admin_role_link.id } }

    subject(:execute) { described_class.new(user, params).execute }

    shared_examples 'returns error' do |error|
      it 'returns an error', :aggregate_failures do
        result = execute
        expect(result).to be_error
        expect(result[:message]).to match error
        expect(Authz::LdapAdminRoleLink.find_by_id(ldap_admin_role_link.id)).to be_present
      end
    end

    context 'without the custom roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it_behaves_like 'returns error', 'custom_roles licensed feature must be available'
    end

    context 'with the custom roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'destroys the target link' do
        expect { execute }.to change { Authz::LdapAdminRoleLink.find_by_id(params[:id]) }.to(nil)
      end

      it 'returns success', :aggregate_failures do
        is_expected.to have_attributes(
          success?: true,
          payload: { ldap_admin_role_link: ldap_admin_role_link }
        )
      end

      context 'when destroy fails' do
        before do
          allow_next_found_instance_of(Authz::LdapAdminRoleLink) do |instance|
            allow(instance).to receive(:destroy).and_return(false)
          end
        end

        it { is_expected.to be_error }
      end

      context 'when id does not match any LDAP admin role link record' do
        let(:params) { { id: non_existing_record_id } }

        it_behaves_like 'returns error', "Couldn't find Authz::LdapAdminRoleLink with 'id'="
      end

      context 'when current user is not an admin' do
        let_it_be(:user) { create(:user) }

        it_behaves_like 'returns error', 'Unauthorized'
      end
    end
  end
end
