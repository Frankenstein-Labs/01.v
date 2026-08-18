# frozen_string_literal: true

FactoryBot.define do
  factory :security_ascp_component_dependency, class: 'Security::Ascp::ComponentDependency' do
    project
    component { association(:security_ascp_component, project: project) }
    dependency { association(:security_ascp_component, project: project) }
  end
end
