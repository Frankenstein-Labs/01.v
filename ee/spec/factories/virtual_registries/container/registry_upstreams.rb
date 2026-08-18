# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_container_registry_upstream,
    class: 'VirtualRegistries::Container::RegistryUpstream' do
    group { registry.group }
    registry { association(:virtual_registries_container_registry) }
    upstream do
      association(
        :virtual_registries_container_upstream,
        group: group,
        registries: [],
        registry_upstreams: []
      )
    end
    sequence(:position) { |n| (n % 5) + 1 }
  end
end
