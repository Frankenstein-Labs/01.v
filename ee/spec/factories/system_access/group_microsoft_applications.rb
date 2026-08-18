# frozen_string_literal: true

FactoryBot.define do
  factory :system_access_group_microsoft_application, class: 'SystemAccess::GroupMicrosoftApplication' do
    enabled { true }
    tenant_xid { generate(:token) }
    client_xid { generate(:token) }
    client_secret { generate(:token) }
    group
  end
end
