# frozen_string_literal: true

module Sbom
  module Ingestion
    module Tasks
      class IngestOccurrencesVulnerabilities < Base
        include Gitlab::Utils::StrongMemoize

        self.model = Sbom::OccurrencesVulnerability
        self.unique_by = %i[sbom_occurrence_id vulnerability_id project_id].freeze
        self.uses = :vulnerability_id

        private

        def existing_records
          Sbom::OccurrencesVulnerability.for_occurrence_ids(occurrence_ids)
        end
        strong_memoize_attr :existing_records

        def occurrence_ids
          insertable_maps.map(&:occurrence_id)
        end

        def existing_links
          existing_records.map do |link|
            {
              sbom_occurrence_id: link.sbom_occurrence_id,
              vulnerability_id: link.vulnerability_id,
              project_id: link.project_id
            }
          end
        end
        strong_memoize_attr :existing_links

        def ingested_links
          insertable_maps.flat_map do |occurrence_map|
            occurrence_map.vulnerability_ids.map do |vulnerability_id|
              {
                sbom_occurrence_id: occurrence_map.occurrence_id,
                vulnerability_id: vulnerability_id,
                project_id: project.id
              }
            end
          end
        end

        def new_links
          ingested_links - existing_links
        end
        alias_method :attributes, :new_links
        strong_memoize_attr :new_links

        def no_longer_present_links
          existing_links - ingested_links
        end
        strong_memoize_attr :no_longer_present_links

        def all_links
          ingested_links + no_longer_present_links
        end

        def after_ingest
          delete_old_links
          sync_elasticsearch
        end

        def delete_old_links
          ids = no_longer_present_links.map do |attributes|
            existing_records.find do |link|
              link.sbom_occurrence_id == attributes[:sbom_occurrence_id] &&
                link.vulnerability_id == attributes[:vulnerability_id]
            end
          end

          Sbom::OccurrencesVulnerability.id_in(ids).each_batch { |batch| batch.delete_all }
        end

        def sync_elasticsearch
          # rubocop:disable CodeReuse/ActiveRecord -- This is Hash#pluck
          # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- This is Hash#pluck
          ids_to_sync = all_links.pluck(:vulnerability_id).uniq
          # rubocop:enable CodeReuse/ActiveRecord
          # rubocop:enable Database/AvoidUsingPluckWithoutLimit

          return unless ids_to_sync.present?

          vulnerabilities = Vulnerability.id_in(ids_to_sync)

          ::Vulnerabilities::BulkEsOperationService.new(vulnerabilities).execute
        end
      end
    end
  end
end
