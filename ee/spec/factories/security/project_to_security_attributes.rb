# frozen_string_literal: true

FactoryBot.define do
  factory :project_to_security_attribute, class: 'Security::ProjectToSecurityAttribute' do
    security_attribute
    traversal_ids { [1, 2, 3] }
  end
end
