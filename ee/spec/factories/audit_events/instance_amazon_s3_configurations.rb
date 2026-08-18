# frozen_string_literal: true

FactoryBot.define do
  factory :instance_amazon_s3_configuration, class: 'AuditEvents::Instance::AmazonS3Configuration' do
    access_key_xid { SecureRandom.hex(8) }
    sequence :bucket_name do |i|
      "bucket-#{i}"
    end
    aws_region { 'ap-south-2' }
    secret_access_key { SecureRandom.hex(8) }
    stream_destination_id { nil }
    active { true }

    trait :inactive do
      active { false }
    end
  end
end
