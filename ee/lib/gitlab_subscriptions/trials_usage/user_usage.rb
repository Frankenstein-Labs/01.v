# frozen_string_literal: true

module GitlabSubscriptions
  module TrialsUsage
    class UserUsage
      include ::Gitlab::Utils::StrongMemoize

      def initialize(trial_usage:)
        @trial_usage = trial_usage
      end

      def total_users_using_credits
        usage_stats[:totalUsersUsingCredits]
      end

      def credits_used
        usage_stats[:creditsUsed]
      end

      def users(username: nil)
        strong_memoize_with(:users, username) do
          case trial_usage.subscription_target
          when :namespace
            namespace_users = users_from_descendant_members

            username.present? ? namespace_users.by_username(username) : namespace_users
          when :instance
            username.present? ? User.by_username(username) : User.all
          end&.human_or_service_user
        end
      end

      def declarative_policy_subject
        trial_usage
      end

      private

      attr_reader :trial_usage

      def usage_stats
        trial_usage_response = trial_usage.subscription_usage_client.get_trial_usage
        trial_usage_response[:trialUsage]&.fetch(:usersUsage, {}) || {}
      end
      strong_memoize_attr :usage_stats

      def users_from_descendant_members
        namespace = trial_usage.namespace
        user_ids = Member.from_union(
          [
            namespace.descendant_project_members_with_inactive.select(:user_id),
            namespace.members_with_descendants.select(:user_id)
          ],
          remove_duplicates: true
        ).select(:user_id)

        User.id_in(user_ids).without_order
      end
    end
  end
end
