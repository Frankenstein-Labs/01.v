# frozen_string_literal: true

FactoryBot.define do
  factory :pm_advisory_data_object, class: '::PackageMetadata::AdvisoryDataObject' do
    advisory_xid { SecureRandom.uuid }
    source_xid { 'glad' }
    published_date { 1.day.ago }
    title { FFaker::Lorem.sentence }
    description { FFaker::Lorem.paragraph }
    cvss_v2 { "AV:N/AC:M/Au:N/C:N/I:P/A:N" }
    cvss_v3 { "CVSS:3.1/AV:N/AC:H/PR:L/UI:N/S:C/C:N/I:L/A:L" }
    cvss_v4 { "CVSS:4.0/AV:L/AC:L/AT:P/PR:L/UI:N/VC:H/VI:N/VA:N/SC:H/SI:N/SA:N" }
    urls { Array.new(2) { FFaker::Internet.uri("https") } }
    identifiers do
      [
        association(:pm_identifier, :cve),
        association(:pm_identifier, :gemnasium)
      ]
    end
    cve { identifiers[0]['name'] }

    affected_packages { [association(:pm_affected_package_data_object)] }

    initialize_with do
      new(**attributes)
    end

    skip_create
  end
end
