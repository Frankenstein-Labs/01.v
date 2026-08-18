# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerabilities_partial_scan, class: 'Vulnerabilities::PartialScan' do
    scan { association(:security_scan) }
    mode { :differential }
  end
end
