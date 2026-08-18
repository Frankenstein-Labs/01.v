# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_packages_maven_upstream_rule,
    class: 'VirtualRegistries::Packages::Maven::Upstream::Rule' do
    remote_upstream { association :virtual_registries_packages_maven_upstream }
    group { remote_upstream.group }
    pattern_type { :wildcard }
    rule_type { :allow }
    target_coordinate { :group_id }
    sequence(:pattern) { |n| "com.example.pattern#{n}.*" }
  end
end
