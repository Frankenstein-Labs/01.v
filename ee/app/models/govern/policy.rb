# frozen_string_literal: true

module Govern
  class Policy < ::SecApplicationRecord
    include Sortable

    self.table_name = 'govern_policies'

    # Bounds the org-wide evaluation read: GOVERN-006 evaluates every policy of an
    # organization per bundle, so an unbounded fetch would grow with the tenant.
    EVALUATION_LIMIT = 100

    belongs_to :organization, class_name: 'Organizations::Organization', optional: false
    belongs_to :namespace, optional: true

    has_many :enforcements,
      class_name: 'Govern::PolicyEnforcement',
      foreign_key: :govern_policy_id,
      inverse_of: :policy

    enum :trigger_type,
      { deployment_requested: 0, environment_advanced: 1, deployment_promoted: 2 },
      prefix: true
    # prefix avoids generating a `warn` scope that clashes with Kernel#warn
    enum :mode, { audit: 0, warn: 1, enforce: 2 }, prefix: true
    enum :lifecycle_state, { active: 0, disabled: 1 }

    scope :for_organization, ->(organization_id) { where(organization_id: organization_id) }
    scope :for_trigger_type, ->(trigger_type) { where(trigger_type: trigger_type) }

    validates :trigger_type, presence: true
    validates :name, presence: true, length: { maximum: 255 }, uniqueness: { scope: :organization_id }
    validates :description, length: { maximum: 4096 }
    validates :scope_rego, length: { maximum: 4096 }
    validates :version, numericality: { only_integer: true, greater_than: 0 }

    # TODO: Validate :rules, :actions, and :policy_scope with JsonSchemaValidator once the
    # authored policy schemas settle in
    # https://gitlab.com/gitlab-org/gitlab/-/work_items/604367. Until then the three
    # columns are listed in spec/support/shared_examples/models/jsonb_column_validation_todo.yml,
    # which marks the coverage check pending. Adding the validators and removing those
    # entries has to happen in the same change: a passing pending example is a failure.

    validate :namespace_matches_organization

    # Fetches one past EVALUATION_LIMIT so the caller can tell a full page from a truncated
    # one. Truncating without noticing would stop enforcing policies silently.
    def self.evaluation_candidates(organization_id:, trigger_type:)
      for_organization(organization_id)
        .active
        .for_trigger_type(trigger_type)
        .order_id_asc
        .limit(EVALUATION_LIMIT + 1)
    end

    private

    # Cells invariant: rows are sharded by organization_id, which must always
    # equal the owning namespace's organization.
    def namespace_matches_organization
      return if namespace.nil? || namespace.organization_id == organization_id

      errors.add(:organization_id, "must match the owning namespace's organization")
    end
  end
end
