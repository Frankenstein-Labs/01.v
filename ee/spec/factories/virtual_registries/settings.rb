# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_setting, class: 'VirtualRegistries::Setting' do
    group

    enabled { true }

    trait :disabled do
      enabled { false }
    end
  end
end
