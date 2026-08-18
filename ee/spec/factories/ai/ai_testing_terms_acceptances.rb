# frozen_string_literal: true

FactoryBot.define do
  factory :ai_testing_terms_acceptances, class: '::Ai::TestingTermsAcceptance' do
    user_id { 1 }
    user_email { 'some_email@gitlab.com' }
  end
end
