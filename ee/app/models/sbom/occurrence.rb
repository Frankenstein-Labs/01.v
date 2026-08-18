# frozen_string_literal: true

module Sbom
  class Occurrence < ::SecApplicationRecord
    COMPONENT_NAME_WITH_C_COLLATION = 'sbom_occurrences.component_name COLLATE "C"'
    LICENSE_COLUMNS = [:spdx_identifier, :name, :url].freeze
    include EachBatch
    include ::Namespaces::Traversal::Traversable
    include Gitlab::Utils::StrongMemoize
    include Ci::Partitionable::AssociationFinder

    attr_writer :policy_dismissals, :malware_vulnerable

    def policy_dismissals
      @policy_dismissals || []
    end

    def malware_vulnerable
      @malware_vulnerable || project
    end

    belongs_to :component, optional: false, inverse_of: :occurrences
    belongs_to :component_version, inverse_of: :occurrences
    belongs_to :project, optional: false
    belongs_to :pipeline, class_name: 'Ci::Pipeline'
    partitionable_belongs_to_loader :pipeline
    belongs_to :source, inverse_of: :occurrences
    belongs_to :source_package, optional: true, inverse_of: :occurrences

    has_many :occurrences_vulnerabilities,
      class_name: 'Sbom::OccurrencesVulnerability',
      foreign_key: :sbom_occurrence_id,
      inverse_of: :occurrence

    has_many :vulnerabilities, through: :occurrences_vulnerabilities

    has_many :sbom_graph_paths_as_descendant,
      foreign_key: :descendant_id,
      class_name: 'Sbom::GraphPath',
      inverse_of: :descendant

    has_many :sbom_graph_paths_as_ancestor,
      foreign_key: :ancestor_id,
      class_name: 'Sbom::GraphPath',
      inverse_of: :ancestor

    has_many :occurrence_refs,
      foreign_key: :sbom_occurrence_id,
      class_name: 'Sbom::OccurrenceRef',
      inverse_of: :occurrence

    enum :highest_severity, ::Enums::Vulnerability.severity_levels
    enum :reachability, ::Enums::Sbom.reachability_types, suffix: true

    validates :commit_sha, presence: true, length: { maximum: 64 }
    validates :uuid, presence: true, uniqueness: { case_sensitive: false }
    validates :package_manager, length: { maximum: 255 }
    validates :component_name, length: { maximum: 255 }
    validates :input_file_path, length: { maximum: 1024 }
    validates :licenses, json_schema: { filename: 'sbom_occurrences-licenses' }

    delegate :name, to: :component
    delegate :purl_type, to: :component
    delegate :component_type, to: :component
    delegate :version, to: :component_version, allow_nil: true
    delegate :source_package_name, to: :component_version, allow_nil: true

    alias_attribute :packager, :package_manager

    scope :order_by_id, -> { order(id: :asc) }

    scope :order_by_component_name, ->(direction) do
      order(component_name: direction)
    end

    scope :order_by_package_name, ->(direction) do
      order(package_manager: direction, component_name: :asc)
    end

    scope :order_by_spdx_identifier, ->(direction, depth: 1) do
      order(Gitlab::Pagination::Keyset::Order.build(
        0.upto(depth).map do |index|
          sql = Arel.sql(
            "COALESCE((licenses -> #{index} ->> 'spdx_identifier'), " \
              "(licenses -> #{index} ->> 'name')) COLLATE \"C\""
          )

          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: "spdx_identifier_#{index}",
            order_expression: direction == "desc" ? sql.desc : sql.asc,
            sql_type: 'text',
            nullable: :nulls_last
          )
        end
      ))
    end

    scope :by_licenses, ->(spdx_identifiers, depth: 1) do
      return none if depth < 0 || spdx_identifiers.blank?

      conditions = (0..depth).map do |depth_level|
        "licenses#>>'{#{depth_level},spdx_identifier}' = ANY(ARRAY[:spdx_identifiers])"
      end

      where(Arel.sql(conditions.join(" OR ")), spdx_identifiers: Array(spdx_identifiers).uniq)
    end

    scope :by_primary_license, ->(spdx_identifiers) do
      by_licenses(spdx_identifiers, depth: 0)
    end

    scope :unarchived, -> { where(archived: false) }

    # This scope helps to use the available index for filter performance
    scope :for_project, ->(project) do
      where(
        traversal_ids: project.namespace.traversal_ids,
        archived: project.archived,
        project_id: project.id
      )
    end

    scope :by_project_ids, ->(project_ids) do
      where(project_id: project_ids)
    end
    scope :by_uuids, ->(uuids) { where(uuid: uuids) }
    scope :for_namespace_and_descendants, ->(namespace) { within(namespace.traversal_ids) }
    scope :by_component_name_prefix, ->(query) do
      sanitized_query = "#{sanitize_sql_like(query)}%"
      where('sbom_occurrences.component_name LIKE ? COLLATE "C"', sanitized_query)
    end
    scope :by_component_name_substring, ->(query) do
      sanitized_query = "%#{sanitize_sql_like(query)}%"
      where('sbom_occurrences.component_name ILIKE ? COLLATE "C"', sanitized_query)
    end
    scope :by_component_name_collated, ->(component_name) do
      where('sbom_occurrences.component_name = ? COLLATE "C"', component_name)
    end
    scope :order_by_component_name_collated, ->(verse = :asc) do
      sql_verse = verse == :asc ? 'ASC' : 'DESC'
      order_sql = "#{COMPONENT_NAME_WITH_C_COLLATION} #{sql_verse}"
      order(order_sql)
    end

    scope :filter_by_package_managers, ->(package_managers) do
      where(package_manager: package_managers)
    end

    scope :with_active_vulnerabilities, -> do
      joins(occurrences_vulnerabilities: :vulnerability)
      .where(vulnerabilities: { state: ::EE::Vulnerability::ACTIVE_STATES })
    end

    scope :with_component_version, -> { where.not(component_version_id: nil) }

    scope :filter_by_components, ->(components) { where(component: components) }
    scope :filter_by_source_packages, ->(source_packages) { where(source_package: source_packages) }
    scope :filter_by_component_names, ->(component_names) do
      where(component_name: component_names)
    end

    scope :filter_by_source_types, ->(source_types) do
      left_outer_joins(:source).where(sbom_sources: { source_type: source_types })
    end

    scope :filter_by_source_id, ->(source_id) do
      where(source_id: source_id)
    end

    scope :filter_by_component_ids, ->(component_ids) do
      where(component_id: component_ids)
    end

    scope :filter_by_component_version_ids, ->(component_version_ids) do
      where(component_version_id: component_version_ids)
    end

    scope :pluck_uuid_and_component_version_id, ->(limit = MAX_PLUCK) do
      limit(limit).pluck(:uuid, :component_version_id)
    end

    # This filter will be used with either project/group(traversal_ids) filter and component selected
    scope :filter_by_non_component_version_ids, ->(component_version_ids) do
      where.not(component_version_id: component_version_ids)
    end

    scope :joins_component_versions, -> { joins(:component_version) }

    scope :filter_by_component_versions, ->(versions) do
      joins_component_versions.where(sbom_component_versions: { version: versions })
    end

    scope :filter_by_non_component_versions, ->(versions) do
      joins_component_versions.where.not(sbom_component_versions: { version: versions })
    end

    scope :filter_by_search_with_component_and_group, ->(search, component_id, group) do
      relation = for_namespace_and_descendants(group)
        .where(component_version_id: component_id)

      if search.present?
        relation.where('input_file_path ILIKE ?', "%#{sanitize_sql_like(search.to_s)}%") # rubocop:disable GitlabSecurity/SqlInjection -- This cop is a false positive as we are using parameterization via ?
      else
        relation
      end
    end

    scope :with_component, -> { includes(:component) }
    scope :with_licenses, -> do
      columns = LICENSE_COLUMNS.map { |column| "#{column} TEXT" }.join(", ")
      sbom_licenses = Arel.sql(<<~SQL.squish)
      LEFT JOIN LATERAL jsonb_to_recordset(sbom_occurrences.licenses) AS sbom_licenses(#{columns}) ON TRUE
      SQL
      joins(sbom_licenses)
        .where("licenses != '[]'")
        .where.not(sbom_licenses: { spdx_identifier: nil })
    end
    scope :with_project_route, -> { preload(project: :route) }
    scope :with_project_namespace, -> { includes(project: [namespace: :route]) }
    scope :with_source, -> { includes(:source) }
    scope :with_version, -> { includes(:component_version) }
    scope :with_pipeline_project_and_namespace, -> {
      with_partition_aware_preload.preload(pipeline: { project: :namespace })
    }
    scope :with_occurrence_refs_for_advisory_scan, -> {
      preload(occurrence_refs: [
        :tracked_context,
        { pipeline: [{ project: :namespace }] }
      ])
    }
    scope :with_vulnerabilities, -> { preload(:vulnerabilities) }
    scope :with_vulnerabilities_and_findings, -> { preload(vulnerabilities: :findings) }
    scope :with_vulnerabilities_vulnerability_reads_and_project, -> {
      preload({ project: [:group] }, vulnerabilities: [:vulnerability_read])
    }
    scope :with_component_source_version_and_project, -> do
      preload(:project).includes(:component, :source, :component_version)
    end
    scope :with_project_setting, -> { preload(project: :project_setting) }
    scope :with_project_security_setting, -> { preload(project: :security_setting) }
    scope :filter_by_non_nil_component_version, -> { where.not(component_version: nil) }

    scope :order_by_severity, ->(direction) do
      order(highest_severity_arel_nodes(direction))
    end

    scope :in_parent_group_after_and_including, ->(sbom_occurrence) do
      where(arel_grouping_by_traversal_ids_and_id.gteq(sbom_occurrence.arel_grouping_by_traversal_ids_and_id))
    end
    scope :in_parent_group_before_and_including, ->(sbom_occurrence) do
      where(arel_grouping_by_traversal_ids_and_id.lteq(sbom_occurrence.arel_grouping_by_traversal_ids_and_id))
    end
    scope :order_traversal_ids_asc, -> do
      reorder(Gitlab::Pagination::Keyset::Order.build([
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'traversal_ids',
          order_expression: arel_table[:traversal_ids].asc,
          nullable: :not_nullable
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: arel_table[:id].asc
        )
      ]))
    end
    scope :filter_by_reachability, ->(reachability) do
      where(reachability: reachability)
    end
    scope :filter_by_vulnerability_id, ->(vulnerability_id) do
      joins(:occurrences_vulnerabilities)
      .where(occurrences_vulnerabilities: { vulnerability_id: vulnerability_id })
    end
    scope :filter_by_vulnerability_occurrence_id, ->(vulnerability_occurrence_id) do
      joins(:occurrences_vulnerabilities)
      .where(occurrences_vulnerabilities: { vulnerability_occurrence_id: vulnerability_occurrence_id })
    end

    scope :with_dependency_paths_existence, -> {
      select(
        arel_table[Arel.star],
        Arel::Nodes::As.new(
          Arel::Nodes::Exists.new(
            Sbom::GraphPath.arel_table
              .project(1)
              .where(Sbom::GraphPath.arel_table[:descendant_id].eq(arel_table[:id]))
              .take(1)
          ),
          Arel.sql('has_dependency_paths')
        )
      )
    }

    scope :filter_by_highest_severity, ->(severity_levels) do
      where(highest_severity: severity_levels)
    end

    scope :ref_orphaned, -> {
      where(
        Sbom::OccurrenceRef.arel_table
          .where(Sbom::OccurrenceRef.arel_table[:sbom_occurrence_id].eq(arel_table[:id]))
          .exists
          .not
      )
    }

    def self.arel_grouping_by_traversal_ids_and_id
      arel_table.grouping([arel_table['traversal_ids'], arel_table['id']])
    end

    def arel_grouping_by_traversal_ids_and_id
      self.class.arel_table.grouping([database_serialized_traversal_ids, id])
    end

    def purl
      return unless purl_type

      purl_namespace, _, purl_name = name.rpartition('/')

      PackageUrl.new(
        type: purl_type,
        namespace: purl_namespace,
        name: purl_name,
        version: version
      )
    end

    def location
      {
        blob_path: input_file_blob_path,
        path: input_file_path,
        top_level: top_level?,
        ancestors: ancestors
      }
    end

    # rubocop:disable Performance/AncestorsInclude -- ancestors here isn't hierarchy related but a model attribute
    def top_level?
      # This solution is to avoid adding a new column to sbom_occurrences.
      # See https://gitlab.com/gitlab-org/security-products/analyzers/dependency-scanning/-/merge_requests/134#note_2369125306
      # for more details.
      ancestors.include?({})
    end
    # rubocop:enable Performance/AncestorsInclude

    def has_dependency_paths?
      # has_dependency_paths is added to the model as a calculated attribute
      # in with_dependency_paths_existence scope
      if attributes.key?('has_dependency_paths')
        attributes['has_dependency_paths']
      else
        sbom_graph_paths_as_descendant.any?
      end
    end
    strong_memoize_attr :has_dependency_paths?

    def malware_status
      ::Vulnerability.malware_status_for(vulnerabilities, malware_vulnerable)
    end

    private

    def input_file_blob_path
      # Project shouldn't be nil, but occasionally an SbomOccurrence could be orphaned when
      # a project is deleted.
      # Tracked in https://gitlab.com/gitlab-org/gitlab/-/issues/541931
      return unless input_file_path.present? && project.present?

      Gitlab::Routing.url_helpers.project_blob_path(project, File.join(commit_sha, input_file_path))
    end

    def self.highest_severity_arel_nodes(direction)
      return Sbom::Occurrence.arel_table[:highest_severity].asc.nulls_first if direction == 'asc'

      Sbom::Occurrence.arel_table[:highest_severity].desc.nulls_last
    end

    def database_serialized_traversal_ids
      self.class.attribute_types['traversal_ids']
                .serialize(traversal_ids)
                .then { |serialized_array| self.class.connection.quote(serialized_array) }
                .then { |quoted_array| Arel::Nodes::SqlLiteral.new(quoted_array) }
    end
  end
end
