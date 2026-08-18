# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_npm_registry, class: 'VirtualRegistries::Packages::Npm::Registry' do
    group

    sequence(:name) { |n| "registry #{n}" }
    description { 'description' }

    transient do
      upstreams_count { 1 }
    end

    trait :with_upstreams do
      registry_upstreams do
        Array.new(upstreams_count) do
          association(:virtual_registries_packages_npm_registry_upstream, registry: instance)
        end
      end

      after(:create) do |entry, _|
        entry.reload # required so that registry.upstreams properly works
      end
    end
  end
end
