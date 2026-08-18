# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_npm_upstream, class: 'VirtualRegistries::Packages::Npm::Upstream' do
    name { 'name' }
    description { 'description' }
    sequence(:url) { |n| "https://gitlab.com/npm/#{n}" }
    auth_token { 'token' }
    registries { [association(:virtual_registries_packages_npm_registry)] }
    group { registries.first.group }
    cache_validity_hours { 24 }
    metadata_cache_validity_hours { 24 }

    after(:build) do |entry, _|
      entry.registry_upstreams.each { |registry_upstream| registry_upstream.group = entry.group }
    end

    trait :without_credentials do
      auth_token { nil }
    end
  end
end
