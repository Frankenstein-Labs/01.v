# frozen_string_literal: true

FactoryBot.modify do
  factory :snippet_repository do
    trait(:checksummed) do
      verification_checksum { 'abc' }
    end

    trait(:checksum_failure) do
      verification_failure { 'Could not calculate the checksum' }
    end

    trait :verification_succeeded do
      verification_checksum { 'abc' }
      verification_state { SnippetRepository.verification_state_value(:verification_succeeded) }
    end

    trait :verification_failed do
      verification_failure { 'Could not calculate the checksum' }
      verification_state { SnippetRepository.verification_state_value(:verification_failed) }
    end
  end
end
