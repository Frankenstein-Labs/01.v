# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_registry_upstream,
    class: 'VirtualRegistries::Packages::Maven::RegistryUpstream' do
    group { registry.group }
    registry { association(:virtual_registries_packages_maven_registry) }
    upstream do
      association(
        :virtual_registries_packages_maven_upstream,
        group: group,
        registries: [],
        registry_upstreams: []
      )
    end
    sequence(:position) { |n| (n % 20) + 1 }

    trait :with_local_upstream do
      upstream { nil }
      local_upstream do
        association(
          :virtual_registries_packages_maven_local_upstream,
          group: group,
          registries: [],
          registry_upstreams: []
        )
      end
    end
  end
end
