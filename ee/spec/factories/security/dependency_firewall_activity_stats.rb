# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_firewall_activity_stat, class: 'Security::DependencyFirewallActivityStat' do
    dependency_firewall_policy_rule
    project
    stat_time { Time.current.beginning_of_hour }
    outcome { :blocked }
    count { 1 }

    # Overrides the enum's auto-generated :allowed trait to also clear the rule (allowed rows have none).
    trait :allowed do
      outcome { :allowed }
      dependency_firewall_policy_rule { nil }
    end
  end
end
