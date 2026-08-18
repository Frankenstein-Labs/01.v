# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_star, class: 'Ai::Catalog::ItemStar' do
    association :user

    item do
      if organization
        association(:ai_catalog_item, organization:)
      else
        association(:ai_catalog_item)
      end
    end

    after(:build) do |star, _|
      star.organization ||= star.item.organization
    end

    trait :without_organization do
      after(:build) do |star, _|
        star.organization = nil
      end
    end
  end
end
