# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_local_upstream,
    class: 'VirtualRegistries::Packages::Maven::Local::Upstream' do
    name { 'name' }
    description { 'description' }
    local_project { association :project }
    metadata_cache_validity_hours { 1 }
    group { association(:group) }

    trait :local_group do
      local_project { nil }
      local_group { association :group }
    end
  end
end
