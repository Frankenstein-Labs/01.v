# frozen_string_literal: true

module QA
  module EE
    FactoryBot.define do
      # https://docs.gitlab.com/ee/api/group_iterations.html
      factory :group_iteration, class: 'QA::EE::Resource::GroupIteration'
    end
  end
end
