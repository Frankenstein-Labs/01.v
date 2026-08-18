# frozen_string_literal: true

FactoryBot.define do
  factory :scim_group_membership, class: 'Authn::ScimGroupMembership' do
    user
    scim_group_uid { SecureRandom.uuid }
  end
end
