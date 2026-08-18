# frozen_string_literal: true

# security_project_tracked_contexts exists to track contexts related to a project to which
# vulnerability information may related and or actively tracked from. In the initial scope
# this is limited to git refs in the traditional static analysis sense, but will likely expand to
# accomodate contexts like job artifacts, logs, packages, containers and more
#
# A record existing in this table does not directly imply tracking, only that the context exists
# and may have vulnerability information related to it. For tracking to be actively enabled against
# that context, the `tracking` field should be set to true

module Security
  class ProjectTrackedContext < ::SecApplicationRecord
    include SafelyChangeColumnDefault
    include ::Gitlab::Utils::StrongMemoize

    self.table_name = 'security_project_tracked_contexts'

    columns_changing_default :is_default

    STATES = { untracked: 1, tracked: 2, archiving: 0, deleting: -1 }.freeze

    # Older vulnerability data uses UUIDs that do not consider the tracked context. This data only
    # exists on the default branch. We describe those as "version 1 vulnerability UUIDs".
    # When we enabled multiple branch tracking we wanted all UUIDs on non-default branches and
    # UUIDs on *newly created default branches* to consider the tracked context. Those are
    # "version 2 vulnerability UUIDs". For consistency and safety, we use the `uuid_version` field
    # set on the tracked context for that ref to be the discriminator between which UUID mechanism
    # to use.
    CONTEXT_UNAWARE_UUID_VERSION = 1
    CONTEXT_AWARE_UUID_VERSION = 2

    belongs_to :project, inverse_of: :security_project_tracked_contexts

    has_many :sbom_occurrence_refs,
      class_name: 'Sbom::OccurrenceRef',
      foreign_key: 'security_project_tracked_context_id',
      inverse_of: :tracked_context
    has_many :vulnerability_reads,
      class_name: 'Vulnerabilities::Read',
      foreign_key: 'security_project_tracked_context_id',
      inverse_of: :tracked_context

    validates :context_name, presence: true, length: { maximum: 1024 }
    validates :context_type, presence: true
    validates :context_name, uniqueness: { scope: [:project_id, :context_type] }
    validate :tracked_refs_limit
    validate :default_ref_cannot_be_untracked, if: :is_default?
    validate :only_branch_refs_can_be_default, if: :is_default?

    before_create :set_traversal_ids

    enum :context_type, {
      branch: 1,
      tag: 2
    }

    state_machine :state, initial: :untracked do
      STATES.each do |state_name, value|
        state state_name, value: value
      end

      event :untrack do
        transition tracked: :untracked
      end

      event :track do
        transition untracked: :tracked
      end

      event :archive do
        transition [:untracked, :tracked] => :archiving
      end

      event :remove do
        transition any => :deleting
      end
    end

    scope :for_project, ->(project_id) { where(project: project_id) }
    scope :default_refs, -> { where(is_default: true) }
    scope :for_context_name, ->(context_name) { where(context_name: context_name) }
    scope :for_context_type, ->(context_type) { where(context_type: context_type) }
    scope :default_branch, -> { for_context_type(:branch).default_refs }
    scope :code_refs, -> { for_context_type([:branch, :tag]) }
    scope :for_ref, ->(ref_name) { for_context_name(ref_name).code_refs }

    scope :for_pipeline, ->(pipeline) do
      context_type = pipeline.tag? ? :tag : :branch

      where(
        project: pipeline.project,
        context_name: pipeline.ref,
        context_type: context_type
      )
    end

    STATES.each do |state_name, value|
      scope state_name, -> { where(state: value) }
    end

    # Maximum number of tracked refs per project (default branch + 3 additional refs)
    MAX_TRACKED_REFS_PER_PROJECT = 4
    # Increased limit for projects with vac_increased_limit feature flag enabled
    MAX_TRACKED_REFS_INCREASED = 1000

    def self.tracked_pipeline?(pipeline)
      for_pipeline(pipeline).tracked.exists?
    end

    def self.find_default_branch_context(project)
      find_by(
        project: project,
        context_name: project.default_branch_or_main,
        context_type: :branch
      )
    end

    # Returns default branch tracked contexts for the given projects, indexed by `project_id`.
    # Performs a single query using a `(project_id, context_name) IN (VALUES ...)` clause to
    # avoid N+1 queries when looking up multiple projects' default branch contexts.
    def self.default_branch_contexts_by_project_id(projects)
      projects = Array.wrap(projects)
      return {} if projects.empty?

      tuples = projects.map { |p| [p.id, p.default_branch_or_main] }
      table = arel_table

      branch.where(
        Arel::Nodes::In.new(
          Arel::Nodes::Grouping.new([table[:project_id], table[:context_name]]),
          Arel::Nodes::ValuesList.new(tuples)
        )
      ).index_by(&:project_id)
    end

    def ref_exists_in_repository?
      return false unless project&.repository_exists?

      case context_type.to_sym
      when :branch
        project.repository.branch_exists?(context_name)
      when :tag
        project.repository.tag_exists?(context_name)
      else
        false
      end
    end
    strong_memoize_attr :ref_exists_in_repository?

    def protected?
      return false unless ref_exists_in_repository?

      case context_type.to_sym
      when :branch
        project.protected_branches.matching(context_name).any?
      when :tag
        project.protected_tags.matching(context_name).any?
      else
        false
      end
    end

    def commit
      return unless ref_exists_in_repository?

      qualified_ref = case context_type.to_sym
                      when :branch then "#{Gitlab::Git::BRANCH_REF_PREFIX}#{context_name}"
                      when :tag then "#{Gitlab::Git::TAG_REF_PREFIX}#{context_name}"
                      end

      return unless qualified_ref

      project.repository.commit(qualified_ref)
    rescue Gitlab::Git::Repository::NoRepository, Gitlab::Git::ReferenceNotFoundError, Rugged::ReferenceError => e
      Gitlab::ErrorTracking.track_exception(e, project_id: project.id, ref_name: context_name)
      nil
    end

    def context_aware_uuids_enabled?
      return true if uuid_version == CONTEXT_AWARE_UUID_VERSION
      return true if uuid_version == CONTEXT_UNAWARE_UUID_VERSION && !is_default?

      false
    end

    private

    def set_traversal_ids
      self.traversal_ids = project.namespace.traversal_ids if traversal_ids.blank?
    end

    def tracked_refs_limit
      return unless tracked?

      tracked_query = self.class.for_project(project_id).tracked
      tracked_query = tracked_query.where.not(id: id) if persisted?

      return unless tracked_query.limit(max_tracked_refs_for_project).count >= max_tracked_refs_for_project

      errors.add(:base, "cannot exceed #{max_tracked_refs_for_project} tracked refs per project")
    end

    def max_tracked_refs_for_project
      @max_tracked_refs_for_project ||= self.class.max_tracked_refs_for_project(project)
    end

    class << self
      def max_tracked_refs_for_project(project)
        return MAX_TRACKED_REFS_INCREASED if Feature.enabled?(:vac_increased_limit, project)

        MAX_TRACKED_REFS_PER_PROJECT
      end
    end

    def default_ref_cannot_be_untracked
      return unless is_default? && !tracked?

      errors.add(:base, 'default ref must be tracked')
    end

    def only_branch_refs_can_be_default
      return if is_default? && branch?

      errors.add(:base, 'only branch refs can be default')
    end
  end
end
