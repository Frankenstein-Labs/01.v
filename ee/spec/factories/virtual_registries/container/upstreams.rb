# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_container_upstream, class: 'VirtualRegistries::Container::Upstream' do
    name { 'name' }
    description { 'description' }
    sequence(:url) { |n| "https://gitlab.com/container/#{n}" }
    username { 'user' }
    password { 'password' }
    registries { [association(:virtual_registries_container_registry)] }
    group { registries.first.group }
    cache_validity_hours { 24 }

    trait :with_auth_url do
      auth_url { 'https://auth.docker.io/token?service=registry.docker.io' }
    end

    after(:build) do |entry, _|
      entry.registry_upstreams.each { |registry_upstream| registry_upstream.group = entry.group }
    end
  end
end
