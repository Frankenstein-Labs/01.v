# frozen_string_literal: true

module QA
  module EE
    FactoryBot.define do
      # https://docs.gitlab.com/ee/api/templates/licenses.html
      factory :license, class: 'QA::EE::Resource::License'
    end
  end
end
