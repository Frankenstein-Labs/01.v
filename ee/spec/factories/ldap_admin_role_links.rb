# frozen_string_literal: true

FactoryBot.define do
  factory :ldap_admin_role_link, class: 'Authz::LdapAdminRoleLink' do
    member_role { association(:member_role) }
    organization { association(:common_organization) }
    provider { 'ldapmain' }
    cn { 'group1' }

    # Use this mainly to skip the validation for provider attribute. Otherwise,
    # Gitlab::Auth::Ldap::Config needs to be stubbed to receive
    # available_servers and return Gitlab::Configs::Options(provider_name: 'ldapmain').
    # See Authz::LdapAdminRoleLink model spec for reference.
    trait :skip_validate do
      to_create { |instance| instance.save!(validate: false) }
    end
  end
end
