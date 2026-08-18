# frozen_string_literal: true

module Sbom
  class OccurrenceRef < ::SecApplicationRecord
    include EachBatch
    include Ci::Partitionable::AssociationFinder
    include ::Elastic::ApplicationVersionedSearch

    self.table_name = 'sbom_occurrence_refs'

    has_many :occurrences_vulnerabilities,
      class_name: 'Sbom::OccurrencesVulnerability',
      foreign_key: :sbom_occurrence_ref_id,
      inverse_of: :occurrence_ref

    belongs_to :project,
      inverse_of: :sbom_occurrence_refs

    belongs_to :occurrence,
      class_name: 'Sbom::Occurrence',
      foreign_key: :sbom_occurrence_id,
      inverse_of: :occurrence_refs

    belongs_to :tracked_context,
      class_name: 'Security::ProjectTrackedContext',
      foreign_key: :security_project_tracked_context_id,
      inverse_of: :sbom_occurrence_refs

    belongs_to :pipeline,
      class_name: 'Ci::Pipeline',
      inverse_of: :sbom_occurrence_refs,
      optional: true
    partitionable_belongs_to_loader :pipeline

    validates :commit_sha, presence: true, length: { maximum: 64 }
    validates :sbom_occurrence_id, presence: true
    validates :security_project_tracked_context_id, presence: true
    validates :project_id, presence: true

    scope :by_occurrence, ->(occurrence_id) { where(sbom_occurrence_id: occurrence_id) }
    scope :by_tracked_context, ->(context_id) { where(security_project_tracked_context_id: context_id) }
    scope :by_project, ->(project_id) { where(project_id: project_id) }
    scope :preload_indexing_data, -> {
      preload(
        :tracked_context,
        { project: :namespace },
        { occurrence: [:source, :component, :component_version, :project, { vulnerabilities: :vulnerability_read }] }
      )
    }

    def self.generate_es_parent(project)
      "group_#{project.namespace.root_ancestor.id}"
    end

    def es_parent
      self.class.generate_es_parent(project)
    end

    def elastic_reference
      ::Search::Elastic::References::Sbom::OccurrenceRef.serialize(self)
    end
  end
end
