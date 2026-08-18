# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_cache_local_entry,
    class: 'VirtualRegistries::Packages::Maven::Cache::Local::Entry' do
    upstream do
      association :virtual_registries_packages_maven_local_upstream
    end
    group { upstream.group }
    package_file { association :package_file }
    sequence(:relative_path) { |n| "/a/relative/path/test-#{n}.txt" }
    upstream_checked_at { 5.minutes.ago }

    trait :upstream_checked do
      upstream_checked_at { 30.minutes.ago }
    end
  end
end
