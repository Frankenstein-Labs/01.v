# frozen_string_literal: true

module QA
  module EE
    FactoryBot.define do
      # https://docs.gitlab.com/ee/api/epics.html
      factory :work_item_epic, class: 'QA::EE::Resource::WorkItemEpic' do
        trait :confidential do
          confidential { true }
        end
      end
    end
  end
end
