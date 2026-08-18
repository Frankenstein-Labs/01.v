# frozen_string_literal: true

FactoryBot.define do
  factory :country_access_log, class: 'Users::CountryAccessLog' do
    user
    country_code { 'CN' }
    first_access_at { Time.zone.now }
    last_access_at { Time.zone.now }
  end
end
