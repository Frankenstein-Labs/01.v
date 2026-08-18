# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_version_dependency, class: 'Ai::Catalog::ItemVersionDependency' do
    ai_catalog_item_version { association(:ai_catalog_item_version, :for_flow) }
    organization { ai_catalog_item_version.organization }
    dependency { association(:ai_catalog_item, :agent) }
  end
end
