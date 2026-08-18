# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_npm_cache_local_entry,
    class: 'VirtualRegistries::Packages::Npm::Cache::Local::Entry' do
    transient do
      local_project { nil }
    end

    upstream do
      association :virtual_registries_packages_npm_upstream,
        :without_credentials,
        url: (local_project || create(:project)).to_global_id.to_s # rubocop:disable RSpec/FactoryBot/InlineAssociation -- local entry doesn't have a project association
    end
    group { upstream.group }
    package_file { association :package_file }
    sequence(:relative_path) { |n| "/a/relative/path/test-#{n}.txt" }

    after(:build) do |entry, _|
      entry.upstream.registry_upstreams.each { |registry_upstream| registry_upstream.group = entry.group }
    end
  end
end
