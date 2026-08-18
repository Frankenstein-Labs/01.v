# frozen_string_literal: true

FactoryBot.define do
  factory :geo_terraform_state_version_state, class: 'Geo::TerraformStateVersionState' do
    terraform_state_version

    trait(:checksummed) do
      verification_checksum { 'abc' }
    end

    trait(:checksum_failure) do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
