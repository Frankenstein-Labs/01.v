# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_mcp_server_block, class: 'Ai::Catalog::McpServerBlock' do
    organization { association(:common_organization) }
    namespace { association(:group, organization: organization) }
    mcp_server { association(:ai_catalog_mcp_server, organization: organization) }

    trait :with_creator do
      created_by { association(:user) }
    end
  end
end
