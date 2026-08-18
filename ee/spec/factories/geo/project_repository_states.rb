# frozen_string_literal: true

FactoryBot.define do
  factory :geo_project_repository_state, class: 'Geo::ProjectRepositoryState' do
    project_repository { association(:project_repository) }
    project { project_repository.project }

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
