# frozen_string_literal: true

module QA
  module EE
    FactoryBot.define do
      # https://docs.gitlab.com/ee/api/group_iterations.html
      factory :group_cadence, class: 'QA::EE::Resource::GroupCadence'
    end
  end
end
