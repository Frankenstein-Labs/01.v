# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_upstream, class: 'VirtualRegistries::Packages::Maven::Upstream' do
    name { 'name' }
    description { 'description' }
    sequence(:url) { |n| "https://gitlab.com/maven/#{n}" }
    username { 'user' }
    password { 'password' }
    registries { [association(:virtual_registries_packages_maven_registry)] }
    group { registries.first.group }
    cache_validity_hours { 24 }
    metadata_cache_validity_hours { 24 }

    after(:build) do |entry, _|
      entry.registry_upstreams.each { |registry_upstream| registry_upstream.group = entry.group }
    end
  end
end
