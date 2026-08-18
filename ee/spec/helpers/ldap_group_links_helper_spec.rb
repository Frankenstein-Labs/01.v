# frozen_string_literal: true

require "spec_helper"

RSpec.describe LdapGroupLinksHelper, feature_category: :system_access do
  describe '#ldap_group_link_input_names' do
    subject(:ldap_group_link_input_names) { helper.ldap_group_link_input_names }

    it 'returns the correct data' do
      expected_data = {
        base_access_level_input_name: "ldap_group_link[group_access]",
        member_role_id_input_name: "ldap_group_link[member_role_id]"
      }

      expect(ldap_group_link_input_names).to match(hash_including(expected_data))
    end
  end

  describe '#ldap_restricted_access_warning?' do
    subject { helper.ldap_restricted_access_warning? }

    context 'when restricted access is enabled' do
      before do
        stub_ee_application_setting(seat_control: ::ApplicationSetting::SEAT_CONTROL_BLOCK_OVERAGES)
      end

      it { is_expected.to be true }
    end

    context 'when restricted access is disabled' do
      it { is_expected.to be false }
    end

    context 'when bso_minimal_access_fallback is disabled' do
      before do
        stub_feature_flags(bso_minimal_access_fallback: false)
      end

      it { is_expected.to be false }
    end
  end

  describe '#ldap_group_link_restricted_access_warning' do
    subject(:ldap_restricted_access_warning) { helper.ldap_restricted_access_warning }

    it 'returns a BSO enabled message' do
      expect(ldap_restricted_access_warning).to include(
        'new users provisioned through LDAP sync are assigned the non-billable Minimal Access role.'
      )
      expect(ldap_restricted_access_warning).to have_link(
        'restricted access',
        href: help_page_path('subscriptions/manage_seats.md', anchor: 'restricted-access')
      )
      expect(ldap_restricted_access_warning).to have_link(
        'provisioning behavior with LDAP',
        href: help_page_path('subscriptions/manage_seats.md',
          anchor: 'provisioning-behavior-with-saml-scim-and-ldap')
      )
    end
  end
end
