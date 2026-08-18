# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_local_upstream_file, class: 'VirtualRegistries::Local::Upstream::File' do
    global_id { 'gid://gitlab/Packages::PackageFile/123' }

    sha1 { 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3' }
    md5 { '09f7e02f1290be211da707a266f153b3' }

    transient do
      file_fixture { 'spec/fixtures/packages/maven/maven-metadata.xml' }
    end

    after(:build) do |file, evaluator|
      file.file = fixture_file_upload(evaluator.file_fixture) if evaluator.file_fixture
    end
  end
end
