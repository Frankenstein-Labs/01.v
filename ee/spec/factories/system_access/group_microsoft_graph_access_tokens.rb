# frozen_string_literal: true

FactoryBot.define do
  factory :system_access_group_microsoft_graph_access_token, class: 'SystemAccess::GroupMicrosoftGraphAccessToken' do
    system_access_group_microsoft_application
    token { generate(:token) }
    expires_in { 3600 }
    group
  end
end
