# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_enabled_namespace, class: '::Search::Zoekt::EnabledNamespace' do
    namespace { association(:namespace) }
  end
end
