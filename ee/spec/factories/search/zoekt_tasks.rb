# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_task, class: '::Search::Zoekt::Task' do
    transient do
      project { nil }
    end

    node { association(:zoekt_node) }
    zoekt_repository do
      project ? association(:zoekt_repository, project: project) : association(:zoekt_repository)
    end
    project_identifier { zoekt_repository.project.id }
    task_type { :index_repo }
    perform_at { 10.minutes.ago }
  end
end
