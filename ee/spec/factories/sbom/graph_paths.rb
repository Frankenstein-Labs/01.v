# frozen_string_literal: true

FactoryBot.define do
  factory :sbom_graph_path, class: 'Sbom::GraphPath' do
    ancestor { association :sbom_occurrence }
    descendant { association :sbom_occurrence }
    path_length { 1 }
    association :project, factory: :project
  end
end
