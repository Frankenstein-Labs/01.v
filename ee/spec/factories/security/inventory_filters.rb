# frozen_string_literal: true

FactoryBot.define do
  factory :security_inventory_filters, class: 'Security::InventoryFilter' do
    project
    archived { false }

    Enums::Security.extended_analyzer_types.each_key do |analyzer_type|
      analyzer_type.to_sym { :not_configured }
    end

    has_scanners { nil }
    has_failed_or_warning { nil }
    has_stale { nil }

    total { 0 }
    critical { 0 }
    high { 0 }
    medium { 0 }
    low { 0 }
    info { 0 }
    unknown { 0 }

    after(:build) do |inv, _|
      inv.project_name = inv.project&.name
      inv.archived = inv.project&.archived
      inv.traversal_ids = inv.project&.namespace&.traversal_ids

      analyzer_values = inv.attributes.values_at(*Security::InventoryFilter::ANALYZER_COLUMNS.map(&:to_s))

      inv.has_scanners = analyzer_values.any? { |v| v != 'not_configured' } if inv.has_scanners.nil?
      inv.has_failed_or_warning = analyzer_values.include?('failed') if inv.has_failed_or_warning.nil?
      inv.has_stale = analyzer_values.include?('stale') if inv.has_stale.nil?
    end

    trait :all_analyzers_enabled do
      sast { :enabled }
      secret_detection { :enabled }
      dependency_scanning { :enabled }
      container_scanning { :enabled }
      dast { :enabled }
      coverage_fuzzing { :enabled }
      api_fuzzing { :enabled }
    end

    trait :all_analyzers_disabled do
      sast { :disabled }
      secret_detection { :disabled }
      dependency_scanning { :disabled }
      container_scanning { :disabled }
      dast { :disabled }
      coverage_fuzzing { :disabled }
      api_fuzzing { :disabled }
    end

    trait :archived_project do
      after(:build) do |inventory_filter|
        inventory_filter.archived = true
      end
    end

    trait :unaggregated do
      has_scanners { false }
      has_failed_or_warning { false }
      has_stale { false }
    end
  end
end
