# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_archive, class: 'Vulnerabilities::Archive' do
    project
    date { Time.zone.today }
  end
end
