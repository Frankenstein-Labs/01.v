# frozen_string_literal: true

FactoryBot.define do
  factory :project_security_statistics, class: 'Security::ProjectStatistics' do
    project
  end
end
