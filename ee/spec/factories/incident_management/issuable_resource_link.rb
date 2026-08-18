# frozen_string_literal: true

FactoryBot.define do
  factory :issuable_resource_link, class: 'IncidentManagement::IssuableResourceLink' do
    association :issue
    link { generate(:url) }
    link_text { 'Incident zoom link' }
    link_type { :zoom }
  end
end
