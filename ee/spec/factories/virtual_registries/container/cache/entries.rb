# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_container_cache_entry,
    class: 'VirtualRegistries::Container::Cache::Entry' do
    upstream { association :virtual_registries_container_upstream }
    group { upstream.group }
    sequence(:relative_path) { |n| "/a/relative/path/test-#{n}.txt" }
    size { 1.kilobyte }
    upstream_etag { "sha256:#{OpenSSL::Digest.hexdigest('SHA256', relative_path)}" }
    content_type { 'text/plain' }
    file_sha1 { '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' }
    status { :default }

    transient do
      file_fixture { 'spec/fixtures/bfg_object_map.txt' }
    end

    after(:build) do |entry, evaluator|
      entry.upstream.registry_upstreams.each { |registry_upstream| registry_upstream.group = entry.group }
      entry.file = fixture_file_upload(evaluator.file_fixture)
    end

    trait :upstream_checked do
      upstream_checked_at { 30.minutes.ago }
      upstream_etag { 'test' }
    end

    trait :with_download_metrics do
      downloads_count { 15 }
      downloaded_at { 30.minutes.ago }
    end
  end
end
