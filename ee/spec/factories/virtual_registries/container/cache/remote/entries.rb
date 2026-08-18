# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_container_cache_remote_entry,
    class: 'VirtualRegistries::Container::Cache::Remote::Entry' do
    upstream { association :virtual_registries_container_upstream }
    group { upstream.group }
    sequence(:relative_path) { |n| "/a/relative/path/test-#{n}.txt" }
    size { 1.kilobyte }
    upstream_etag { OpenSSL::Digest.hexdigest('SHA256', 'test') }
    content_type { 'application/octet-stream' }
    digest { VirtualRegistries::Container.extract_digest_from_path(relative_path) }
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
