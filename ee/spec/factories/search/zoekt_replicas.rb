# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_replica, class: '::Search::Zoekt::Replica' do
    zoekt_enabled_namespace { association(:zoekt_enabled_namespace) }
    namespace_id { zoekt_enabled_namespace.root_namespace_id }

    trait :ready do
      state { Search::Zoekt::Replica.states.fetch(:ready) }
    end
  end
end
