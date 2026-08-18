# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_repository, class: '::Search::Zoekt::Repository' do
    project { association(:project) }
    zoekt_index { association(:zoekt_index) }
    project_identifier { project.id }
    state { Search::Zoekt::Repository.states.fetch(:pending) }
    size_bytes { 10.megabytes }

    trait :with_repo do
      project { association(:project_with_repo) }
    end
  end

  trait :orphaned do
    state { Search::Zoekt::Repository.state_value(:orphaned) }
  end
end
