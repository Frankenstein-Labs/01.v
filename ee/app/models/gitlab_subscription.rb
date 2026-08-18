# frozen_string_literal: true

class GitlabSubscription < ApplicationRecord
  include EachBatch
  include Gitlab::Utils::StrongMemoize
  include AfterCommitQueue

  SUBSCRIPTION_GRACE_PERIOD = 14.days.freeze

  enum :trial_extension_type, { extended: 1, reactivated: 2 }

  attribute :start_date, default: -> { Time.zone.today }

  before_validation :set_hosted_plan_name_uid

  before_update :set_max_seats_used_changed_at
  before_update :log_previous_state_for_update, if: :tracked_attributes_changed?
  before_update :reset_seat_statistics
  before_update :publish_subscription_renewed_event

  after_commit :reset_seats_usage_callouts, on: :update
  after_commit :index_namespace, on: [:create, :update]
  after_destroy_commit :log_previous_state_for_destroy

  belongs_to :namespace
  belongs_to :hosted_plan, class_name: 'Plan'

  validates :seats, :start_date, presence: true
  validates :namespace_id, uniqueness: true, presence: true

  validates :trial_ends_on, :trial_starts_on, presence: true, if: :trial?
  validates_comparison_of :trial_ends_on, greater_than: :trial_starts_on, if: :trial?
  validates :hosted_plan_name_uid, presence: true, if: :hosted_plan_id?
  validates :contract_overages_allowed, inclusion: { in: [true, false] }

  delegate :name, :title, to: :hosted_plan, prefix: :plan, allow_nil: true
  delegate :exclude_guests?, to: :namespace

  scope :by_hosted_plan_ids, ->(plan_ids) do
    where(hosted_plan_id: plan_ids)
  end

  scope :with_hosted_plan, ->(plan_name) do
    joins(:hosted_plan).where(trial: [false, nil], 'plans.name' => plan_name)
    .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422013')
  end

  scope :with_a_paid_hosted_plan, -> do
    with_hosted_plan(Plan::PAID_HOSTED_PLANS)
  end

  scope :with_a_paid_or_trial_hosted_plan, -> do
    joins(:hosted_plan).where('plans.name' => Plan::PAID_HOSTED_PLANS)
    .allow_cross_joins_across_databases(url: 'https://gitlab.com/gitlab-org/gitlab/-/issues/422013')
  end

  scope :with_active_paid_or_trial_hosted_plan, ->(grace_period = 0) do
    with_a_paid_hosted_plan.not_expired(before_date: Date.current - grace_period).or(
      with_a_paid_or_trial_hosted_plan.where(trial: true, trial_ends_on: (Date.current - grace_period)..)
    )
  end
  scope :id_greater_than, ->(id) { where(arel_table[:id].gt(id)) }
  scope :preload_for_refresh_seat, -> { preload([{ namespace: :route }, :hosted_plan]) }
  scope :with_namespace_settings, -> { joins(namespace: :namespace_settings).includes(namespace: :namespace_settings) }

  scope :max_seats_used_changed_between, ->(from:, to:) do
    where(max_seats_used_changed_at: from..to)
  end

  scope :requiring_seat_refresh, ->(limit) do
    # look for subscriptions that have not been refreshed in more than
    # 18 hours (catering for 6-hourly refresh schedule)
    with_a_paid_hosted_plan
      .where("last_seat_refresh_at < ? OR last_seat_refresh_at IS NULL", 18.hours.ago)
      .limit(limit)
  end

  scope :not_expired, ->(before_date: Time.zone.today) { where('end_date IS NULL OR end_date >= ?', before_date) }

  scope :namespace_id_in, ->(namespace_ids) do
    where(namespace_id: namespace_ids)
  end

  def calculate_seats_in_use
    namespace.billable_members_count
  end

  # The purpose of max_seats_used is similar to what we do for EE licenses
  # with the historical max. We want to know how many extra users the customer
  # has added to their group (users above the number purchased on their subscription).
  # Then, on the next month we're going to automatically charge the customers for those extra users.
  def calculate_seats_owed
    return 0 unless has_a_paid_hosted_plan?

    [0, max_seats_used - seats].max
  end

  def seats_remaining
    [0, seats - max_seats_used.to_i].max
  end

  # Refresh seat related attribute (without persisting them)
  def refresh_seat_attributes(reset_max: false)
    self.seats_in_use = calculate_seats_in_use
    self.max_seats_used = reset_max ? seats_in_use : [max_seats_used, seats_in_use].max
    self.seats_owed = calculate_seats_owed
  end

  def has_a_paid_hosted_plan?
    !trial? && seats > 0 && Plan::PAID_HOSTED_PLANS.include?(plan_name)
  end

  def expired?
    return false unless end_date

    end_date < Date.current
  end

  def paid_and_expired?
    has_a_paid_hosted_plan? && expired?
  end

  def upgradable?
    return false if ::Plan::TOP_PLANS.include?(plan_name)

    has_a_paid_hosted_plan? && !expired?
  end

  def plan_code=(code)
    code ||= Plan::FREE

    self.hosted_plan = Plan.find_by(name: code)
  end

  # We need to show seats in use for free or trial subscriptions
  # in order to make it easy for customers to get this information.
  def seats_in_use
    return super if has_a_paid_hosted_plan?

    seats_in_use_now
  end

  def trial_extended_or_reactivated?
    trial_extension_type.present?
  end

  private

  def seats_in_use_now
    calculate_seats_in_use
  end
  strong_memoize_attr :seats_in_use_now

  def log_previous_state_for_update
    attrs = attributes.merge(attributes_in_database)

    GitlabSubscriptions::SubscriptionHistory.create_from_change(:gitlab_subscription_updated, attrs)
  end

  def log_previous_state_for_destroy
    GitlabSubscriptions::SubscriptionHistory.create_from_change(:gitlab_subscription_destroyed, attributes)
  end

  def automatically_index_in_elasticsearch?
    return false unless ::Gitlab::Saas.feature_available?(:advanced_search)
    return false if expired?

    # We only index paid groups or trials on dot com for now.
    Plan::PAID_HOSTED_PLANS.include?(plan_name)
  end

  # Kick off Elasticsearch indexing for paid groups with new or upgraded paid, hosted subscriptions
  # Uses safe_find_or_create_by to avoid ActiveRecord::RecordNotUnique exception when upgrading from
  # one paid plan to another paid plan
  def index_namespace
    return unless automatically_index_in_elasticsearch?

    ElasticsearchIndexedNamespace.safe_find_or_create_by!(namespace_id: namespace_id)
  end

  # If the subscription changes, we reset max_seats_used and seats_owed
  # if they're out of date, so that we don't carry them over from the previous term/subscription.
  # One exception is the plan switch between `premium` and `ultimate_trial_paid_customer`.
  def reset_seat_statistics
    return unless reset_seat_statistics?

    refresh_seat_attributes(reset_max: true)
    self.max_seats_used_changed_at = Time.current
  end

  def publish_subscription_renewed_event
    return unless new_term?

    run_after_commit do
      Gitlab::EventStore.publish(GitlabSubscriptions::RenewedEvent.new(data: { namespace_id: namespace_id }))
    end
  end

  def set_max_seats_used_changed_at
    return if new_term? || !max_seats_used_changed?

    self.max_seats_used_changed_at = Time.current
  end

  def new_term?
    persisted? && start_date_changed? && end_date_changed? &&
      (end_date_was.nil? || start_date >= end_date_was)
  end

  def reset_seat_statistics?
    return reset_involves_ultimate_trial_paid_customer_plan? if involves_ultimate_trial_paid_customer_plan?
    return false unless has_a_paid_hosted_plan?
    return true if new_term?
    return true if trial_changed? && !trial

    max_seats_used_changed_at.present? && max_seats_used_changed_at.to_date < start_date
  end

  def ultimate_trial_paid_customer_plan_id
    ::Plan.find_by(name: ::Plan::ULTIMATE_TRIAL_PAID_CUSTOMER)&.id
  end
  strong_memoize_attr :ultimate_trial_paid_customer_plan_id

  def premium_plan_id
    ::Plan.find_by(name: ::Plan::PREMIUM)&.id
  end
  strong_memoize_attr :premium_plan_id

  def involves_ultimate_trial_paid_customer_plan?
    return false unless ultimate_trial_paid_customer_plan_id

    ultimate_trial_paid_customer_plan_id.in?([hosted_plan_id, hosted_plan_id_was])
  end

  def reset_involves_ultimate_trial_paid_customer_plan?
    # Do not reset if plan unchanged on ultimate_trial_paid_customer_plan
    return false unless hosted_plan_id_changed?

    # Do not reset if switching to ultimate_trial_paid_customer_plan
    return false if hosted_plan_id == ultimate_trial_paid_customer_plan_id

    # Now hosted_plan_id_was must be ultimate_trial_paid_customer_plan_id
    return false if hosted_plan_id == premium_plan_id && premium_plan_not_renewed?

    # Either the premium plan was renewed, or it is upgrading to ultimate plan
    true
  end

  def premium_plan_not_renewed?
    previous_premium_gs = GitlabSubscriptions::SubscriptionHistory
                            .where(gitlab_subscription_id: id, hosted_plan_id: premium_plan_id).order(:id).last

    previous_premium_gs&.start_date == start_date && previous_premium_gs&.end_date == end_date
  end

  def tracked_attributes_changed?
    changed.intersection(GitlabSubscriptions::SubscriptionHistory::TRACKED_ATTRIBUTES).any?
  end

  def reset_seats_usage_callouts
    return unless saved_change_to_seats?

    Groups::ResetSeatCalloutsWorker.perform_async(namespace_id)
  end

  def set_hosted_plan_name_uid
    return if hosted_plan_name_uid.present? && !hosted_plan_id_changed?

    self.hosted_plan_name_uid = hosted_plan&.plan_name_uid_before_type_cast
  end
end

# Added for JiHu
# Used in https://jihulab.com/gitlab-cn/gitlab/-/blob/main-jh/jh/app/models/jh/gitlab_subscription.rb
GitlabSubscription.prepend_mod
