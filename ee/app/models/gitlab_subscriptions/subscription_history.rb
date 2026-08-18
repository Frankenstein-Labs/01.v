# frozen_string_literal: true

# GitlabSubscriptions::SubscriptionHistory records the previous value before change.
module GitlabSubscriptions
  class SubscriptionHistory < ApplicationRecord
    self.table_name = 'gitlab_subscription_histories'

    # `gitlab_subscription_created` change_type (id: 0) doesn't exist because there's no previous value before creation
    enum :change_type, {
      gitlab_subscription_updated: 1,
      gitlab_subscription_destroyed: 2
    }

    belongs_to :namespace, optional: false
    belongs_to :hosted_plan, class_name: 'Plan', inverse_of: :gitlab_subscription_histories

    validates :gitlab_subscription_id, presence: true

    PREFIXED_ATTRIBUTES = %w[
      id
      created_at
      updated_at
    ].freeze

    TRACKED_ATTRIBUTES = %w[
      start_date
      end_date
      trial_ends_on
      namespace_id
      hosted_plan_id
      hosted_plan_name_uid
      seats_in_use
      max_seats_used
      seats
      trial
      trial_starts_on
      auto_renew
      trial_extension_type
      contract_overages_allowed
    ].freeze

    # Attributes can be added to this list if they should not be tracked by the history table.
    # By default, attributes should be tracked, and only added to this list if there is a
    # good reason not to.
    # We don't use this list other than to raise awareness of which attributes we should not track.
    OMITTED_ATTRIBUTES = %w[
      seats_owed
      max_seats_used_changed_at
      last_seat_refresh_at
    ].freeze

    scope :with_all_ultimate_plans, -> do
      joins(:hosted_plan).where(hosted_plan: { name: EE::Plan::ALL_ULTIMATE_PLANS })
    end

    scope :ended_on, ->(date) { where(end_date: date) }

    scope :with_namespace_subscription, -> { includes(namespace: [gitlab_subscription: :hosted_plan]) }

    def self.create_from_change(change_type, attrs)
      create_attrs = attrs
        .slice(*TRACKED_ATTRIBUTES)
        .merge(change_type: change_type)

      PREFIXED_ATTRIBUTES.each do |attr_name|
        create_attrs["gitlab_subscription_#{attr_name}"] = attrs[attr_name]
      end

      create(create_attrs)
    end

    def declarative_policy_subject
      namespace
    end
  end
end
