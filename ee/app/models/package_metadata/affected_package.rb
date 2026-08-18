# frozen_string_literal: true

module PackageMetadata
  class AffectedPackage < ApplicationRecord
    include Gitlab::Utils::StrongMemoize
    include BulkInsertSafe
    include EachBatch

    belongs_to :advisory, class_name: 'PackageMetadata::Advisory', optional: false, foreign_key: :pm_advisory_id,
      inverse_of: :affected_packages

    enum :purl_type, ::Enums::Sbom.purl_types

    validates :purl_type, presence: true
    validates :package_name, presence: true, length: { maximum: 256 }
    validates :distro_version, length: { maximum: 256 }
    validates :solution, length: { maximum: 2048 }
    validates :affected_range, presence: true, length: { maximum: 512 }
    validates :overridden_advisory_fields, json_schema: { filename: 'pm_affected_package_overridden_advisory_fields' }
    validates :fixed_versions, length: { maximum: 10 }
    validates :versions, json_schema: { filename: 'pm_affected_package_versions' }

    scope :for_occurrences, ->(occurrences) { with(occurrence_cte(occurrences)).joins(occurrence_cte_join) }

    scope :with_advisory, -> { includes(:advisory).distinct }

    def self.occurrence_cte(occurrences)
      occurrence_data = occurrences.map do |occ|
        [::Enums::Sbom.purl_types[occ.purl_type], occ.name]
      end

      Arel::Nodes::As.new(
        Hashie::Mash.new(
          name: Arel.sql('occurrences_cte(purl_type, name)')
        ), Arel::Nodes::Grouping.new(Arel::Nodes::ValuesList.new(occurrence_data))
      )
    end

    def self.occurrence_cte_join
      'INNER JOIN occurrences_cte ON occurrences_cte.purl_type = pm_affected_packages.purl_type ' \
        'AND occurrences_cte.name = pm_affected_packages.package_name'
    end

    def solution_text
      return solution if solution.present?

      # This is a Container Scanning affected package, check for presence of fixed_versions.
      explicit_fixed_version = fixed_versions.delete_if { |v| v == '*' }
      return 'Unfortunately, there is no solution available yet.' if explicit_fixed_version.empty?

      "Upgrade to version #{explicit_fixed_version.join(', ')} or above"
    end
  end
end
