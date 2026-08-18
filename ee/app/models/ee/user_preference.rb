# frozen_string_literal: true

module EE
  module UserPreference
    extend ActiveSupport::Concern

    # Derived from the single source of truth in Ai::Orbit::Settings::SUBSETTINGS.
    # Used by the preferences controller to permit subsetting params and
    # to define dynamic accessors below.
    ORBIT_SUBSETTINGS = ::Ai::Orbit::Settings::SUBSETTINGS.values.freeze

    prepended do
      extend ::Gitlab::Utils::Override

      belongs_to :default_duo_add_on_assignment, class_name: 'GitlabSubscriptions::UserAddOnAssignment', optional: true
      belongs_to :duo_default_namespace, class_name: 'Namespace', optional: true
      belongs_to :knowledge_graph_governing_namespace, class_name: 'Namespace', optional: true

      validates :orbit_settings, json_schema: { filename: 'user_preference_orbit_settings', size_limit: 1.kilobyte }

      validates :roadmap_epics_state, allow_nil: true, inclusion: {
        in: ::Epic.available_states.values, message: "%{value} is not a valid epic state id"
      }

      validates :epic_notes_filter, inclusion: { in: ::UserPreference::NOTES_FILTERS.values }, presence: true

      validate :check_seat_for_default_duo_assigment, if: :default_duo_add_on_assignment_id_changed?
      validate :validate_duo_default_namespace_id, if: :duo_default_namespace_id_changed?
      validate :validate_knowledge_graph_governing_namespace_id, if: :knowledge_graph_governing_namespace_id_changed?

      def duo_default_namespace_candidates
        if ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
          membership_uids = GitlabSubscriptions::AddOn.uids_for_names([:duo_core, :gitlab_credits])
          duo_assignable_uids =
            GitlabSubscriptions::AddOn.uids_for_names(::GitlabSubscriptions::AddOn::SEAT_ASSIGNABLE_DUO_ADD_ONS)
          add_on_uid_column = GitlabSubscriptions::AddOnPurchase.arel_table[:subscription_add_on_uid]

          namespace_ids_subquery = GitlabSubscriptions::AddOnPurchase
            .for_duo_add_ons
            .active.for_user(user)
            .left_outer_joins(:assigned_users)
            .where(
              add_on_uid_column.in(membership_uids).or(
                add_on_uid_column.in(duo_assignable_uids)
                  .and(GitlabSubscriptions::UserAddOnAssignment.arel_table[:id].not_eq(nil))
              )
            )
            .distinct
            .select(:namespace_id)

          ::Namespace.where(id: namespace_ids_subquery)
        else
          ::Namespace.where(id: user.authorized_groups.top_level)
        end
      end

      validates :policy_advanced_editor, allow_nil: false, inclusion: { in: [true, false] }

      attribute :policy_advanced_editor, default: false

      scope :policy_advanced_editor, -> { where(policy_advanced_editor: true) }

      # EE:SaaS - namespace with seats for SAAS purpose only
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/557584
      def eligible_duo_add_on_assignments
        assignable_enum_value = ::GitlabSubscriptions::AddOn.names.values_at(
          *::GitlabSubscriptions::AddOn::SEAT_ASSIGNABLE_DUO_ADD_ONS
        )

        GitlabSubscriptions::UserAddOnAssignment
                                    .by_user(user)
                                    .with_namespaces
                                    .joins(add_on_purchase: :add_on)
                                    .where(add_on_purchase: { subscription_add_ons: { name: assignable_enum_value } })
                                    .where.not(add_on_purchase: { namespace_id: nil })
      end

      def distinct_eligible_duo_add_on_assignments
        distinct_query = 'DISTINCT ON (add_on_purchase.namespace_id) subscription_user_add_on_assignments.*'

        eligible_duo_add_on_assignments.select(distinct_query)
      end

      def check_seat_for_default_duo_assigment
        return if default_duo_add_on_assignment_id.nil?

        return if eligible_duo_add_on_assignments.exists?(id: default_duo_add_on_assignment_id)

        errors.add(:default_duo_add_on_assignment_id,
          "No Duo seat assignments with namespace found with ID #{default_duo_add_on_assignment_id}")
      end

      def no_eligible_duo_add_on_assignments?
        eligible_duo_add_on_assignments.none?
      end

      def duo_default_namespace_with_fallback
        namespace = duo_default_namespace

        return namespace if namespace

        # fallback to deprecated assignment-based approach
        return default_duo_add_on_assignment.namespace if default_duo_add_on_assignment.present?

        # fallback if only one candidate exists
        namespaces = duo_default_namespace_candidates.limit(2).to_a

        namespaces.first if namespaces.size == 1
      end

      override :duo_default_namespace
      def duo_default_namespace
        namespace = super
        namespace if namespace && duo_default_namespace_candidates.where(id: namespace.id).exists?
      end

      def duo_default_namespace_id=(namespace_id)
        # Prevent fallback to assignment id in future reads
        self.default_duo_add_on_assignment_id = nil if namespace_id.nil?
        super
      end

      # ---- Orbit settings accessors ----
      # The main `enabled` flag is a killswitch for all Orbit functionality.
      # Subsettings default to true when the killswitch is on so existing
      # opt-in users keep all flows.

      def orbit_enabled
        orbit_settings.fetch('enabled', false)
      end

      def orbit_enabled=(value)
        cast_value = ActiveModel::Type::Boolean.new.cast(value)

        self.orbit_settings = orbit_settings.merge('enabled' => cast_value)
      end

      EE::UserPreference::ORBIT_SUBSETTINGS.each do |key|
        define_method(key) do
          # Subsettings only apply when the main killswitch is on. When the
          # killswitch is off, subsettings always read as false. When the
          # killswitch is on but the subsetting key is absent, default to true
          # so users who opt in get all Orbit features by default.
          return false unless orbit_enabled

          orbit_settings.fetch(key, true)
        end

        define_method(:"#{key}=") do |value|
          cast_value = ActiveModel::Type::Boolean.new.cast(value)

          self.orbit_settings = orbit_settings.merge(key => cast_value)
        end
      end

      def knowledge_graph_governing_namespace_with_fallback
        knowledge_graph_governing_namespace || knowledge_graph_governing_namespace_finder.single_candidate_fallback
      end

      override :knowledge_graph_governing_namespace
      def knowledge_graph_governing_namespace
        return unless knowledge_graph_governing_namespace_id
        return unless knowledge_graph_governing_namespace_finder.eligible?(knowledge_graph_governing_namespace_id)

        super
      end

      private

      def validate_duo_default_namespace_id
        return unless duo_default_namespace_id

        return if duo_default_namespace_candidates.where(id: duo_default_namespace_id).exists?

        errors.add(:duo_default_namespace_id)
      end

      def validate_knowledge_graph_governing_namespace_id
        return unless knowledge_graph_governing_namespace_id
        return if knowledge_graph_governing_namespace_finder.eligible?(knowledge_graph_governing_namespace_id)

        errors.add(:knowledge_graph_governing_namespace_id)
      end

      def knowledge_graph_governing_namespace_finder
        ::Analytics::KnowledgeGraph::GoverningNamespaceFinder.new(user)
      end
    end
  end
end
