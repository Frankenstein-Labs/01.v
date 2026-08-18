# frozen_string_literal: true

FactoryBot.define do
  factory :audit_events_instance_external_streaming_destination,
    class: 'AuditEvents::Instance::ExternalStreamingDestination' do
    category { 'http' }
    config { { url: FFaker::Internet.uri('https') } }
    secret_token { 'a' * 20 }
    legacy_destination_ref { nil }
    active { true }

    trait :inactive do
      active { false }
    end
    trait :aws do
      category { 'aws' }
      config do
        {
          accessKeyXid: SecureRandom.hex(8),
          bucketName: SecureRandom.hex(8),
          awsRegion: "ap-south-2"
        }
      end
      secret_token { SecureRandom.hex(8) }
    end

    trait :gcp do
      category { 'gcp' }
      config do
        {
          googleProjectIdName: "#{FFaker::Lorem.word.downcase}-#{SecureRandom.hex(4)}",
          clientEmail: FFaker::Internet.safe_email,
          logIdName: "audit_events"
        }
      end
      secret_token { OpenSSL::PKey::RSA.new(4096).to_pem }
    end
  end
end
