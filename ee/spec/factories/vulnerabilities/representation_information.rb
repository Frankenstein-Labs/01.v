# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_representation_information, class: 'Vulnerabilities::RepresentationInformation' do
    association :vulnerability, factory: :vulnerability
    resolved_in_commit_sha { Digest::SHA256.hexdigest(SecureRandom.hex(50)) }

    after(:build) do |information, _|
      information.project = information.vulnerability&.project
    end
  end
end
