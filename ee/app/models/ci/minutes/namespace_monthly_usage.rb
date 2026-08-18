# frozen_string_literal: true

module Ci
  module Minutes
    # Track compute usage at root namespace level.
    # This class ensures that we keep MAX_NUMBER_OF_SHARDS record per namespace per month.
    # The number could eventually be modified, so the code supports variable shard numbers per month
    class NamespaceMonthlyUsage < Ci::ApplicationRecord
      include Ci::NamespacedModelName
      include AfterCommitQueue

      MAX_NUMBER_OF_SHARDS = 10

      belongs_to :namespace

      validates :shard_number,
        numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_NUMBER_OF_SHARDS }
      validates :shard_number, uniqueness: { scope: [:namespace_id, :date] }

      scope :current_month, -> { where(date: beginning_of_month) }
      scope :for_namespace, ->(namespace) { where(namespace: namespace) }
      scope :by_namespace_and_date, ->(namespace, date) {
        where(namespace: namespace, date: date)
      }

      # Captures all shards of the last recorded month
      def self.all_previous_usages(namespace)
        date_subquery = for_namespace(namespace)
                          .where("#{quoted_table_name}.date < :date", date: beginning_of_month)
                          .select("MAX(#{quoted_table_name}.date)")

        by_namespace_and_date(namespace, date_subquery)
      end

      def self.beginning_of_month(time = Time.current)
        time.utc.beginning_of_month
      end

      def self.all_current_usages(namespace_id)
        current_month.for_namespace(namespace_id)
      end

      def self.total_current_minutes_used(namespace_id)
        all_current_usages(namespace_id).sum(:amount_used).to_i
      end

      # We should always use this method to access data for the current month
      # since this will lazily create an entry if it doesn't exist.
      # For example, on the 1st of each month, when we update the usage for a namespace,
      # we will automatically generate new records and reset usage for the current month.
      # This also recalculates any additional compute minutes based on the previous month usage.
      def self.find_or_create_current(namespace_id:)
        current_usage = unsafe_find_current(namespace_id)
        return current_usage if current_usage

        return current_month.for_namespace(namespace_id).new if ::Gitlab::Database.read_only?

        current_month.for_namespace(namespace_id).new.tap do |new_usage|
          # TODO: Remove in https://gitlab.com/gitlab-org/gitlab/-/issues/350617
          # Avoid cross-database modifications in transaction since
          # recalculation of purchased compute minutes touches `namespaces` table.
          new_usage.run_after_commit do
            Namespace.find_by_id(namespace_id).try do |namespace|
              Ci::Minutes::Quota.new(namespace).recalculate_remaining_purchased_minutes!
              Ci::Minutes::RefreshCachedDataWorker.perform_async(namespace_id) # rubocop:disable CodeReuse/Worker
            end
          end

          new_usage.save!
        end
      rescue ActiveRecord::RecordNotUnique
        unsafe_find_current(namespace_id)
      end

      def increase_usage(increments)
        increment_params = increments.select { |_attribute, value| value > 0 }
        return if increment_params.empty?

        # The use of `update_counters` ensures we do a SQL update rather than
        # incrementing the counter for the object in memory and then save it.
        # This is better for concurrent updates.
        self.class.update_counters(self, increment_params)
      end

      def self.reset_current_usage(namespace)
        update_current(namespace, amount_used: 0, notification_level: Notification::PERCENTAGES.fetch(:not_set))
      end

      def self.reset_current_notification_level(namespace)
        update_current(namespace, notification_level: Notification::PERCENTAGES.fetch(:not_set))
      end

      def self.update_current(namespace, attributes)
        current_month.for_namespace(namespace).update_all(attributes)
      end
      private_class_method :update_current

      # This is unsafe to use publicly because it would read the data
      # without creating a new record if doesn't exist.
      def self.unsafe_find_current(namespace)
        current_month.for_namespace(namespace).take
      end
      private_class_method :unsafe_find_current

      # Notification_level is set to 100 (meaning 100% remaining compute minutes) by default.
      # It is reduced to 30 when the quota available drops below 30%
      # It is reduced to 5 when the quota available drops below 5%
      # It is reduced to 0 when the there are no more compute minutes available.
      #
      # Legacy tracking of compute usage (in `namespaces` table) uses 2 attributes instead.
      # We are condensing both into `notification_level` in the new monthly tracking.
      #
      # Until we retire the legacy compute usage tracking:
      #   * notification_level == 0 is equivalent to last_ci_minutes_notification_at being set
      #   * notification_level between 100 and 0 is equivalent to last_ci_minutes_usage_notification_level
      #     being set
      #   * notification_level == 100 is equivalent to neither of the legacy attributes being set,
      #     meaning that the quota used is still in the bucket 100%-to-30% used.
      #
      # Queries all shards rather than a single row so that a notification
      # recorded on one shard is visible even after writes are distributed
      # across shards (reference: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/224699
      # and https://gitlab.com/gitlab-org/gitlab/-/work_items/490968 ).
      def self.any_usage_notified?(namespace_id, remaining_percentage)
        all_current_usages(namespace_id).where(notification_level: remaining_percentage).exists?
      end

      def self.any_total_usage_notified?(namespace_id)
        any_usage_notified?(namespace_id, Notification::PERCENTAGES.fetch(:exceeded))
      end
    end
  end
end
