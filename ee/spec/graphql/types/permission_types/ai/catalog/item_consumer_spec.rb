# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PermissionTypes::Ai::Catalog::ItemConsumer, feature_category: :workflow_catalog do
  specify do
    expected_permissions = %i[
      read_ai_catalog_item_consumer
      admin_ai_catalog_item_consumer
    ]

    expected_permissions.each do |permission|
      expect(described_class).to have_graphql_field(permission)
    end
  end
end
