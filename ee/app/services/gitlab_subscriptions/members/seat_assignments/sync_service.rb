# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    module SeatAssignments
      class SyncService
        BATCH_SIZE = 100

        def initialize(user_ids, root_namespace)
          @user_ids = user_ids.compact.uniq
          @root_namespace = root_namespace
        end

        def execute
          return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
          return user_namespace_error if root_namespace.user_namespace?

          user_ids.each_slice(BATCH_SIZE) do |batch_user_ids|
            seats_to_remove, seats_to_upsert = seat_type_mappings(batch_user_ids)

            upsert_seat_assignments(seats_to_upsert) if seats_to_upsert.any?
            remove_seat_assignments(seats_to_remove) if seats_to_remove.any?
          end

          ServiceResponse.success
        end

        private

        attr_reader :user_ids, :root_namespace

        def upsert_seat_assignments(seats_to_upsert)
          seat_assignments = seats_to_upsert.map { |user_id, seat_type| seat_assignment(user_id, seat_type) }

          GitlabSubscriptions::SeatAssignment.upsert_all(seat_assignments, unique_by: [:namespace_id, :user_id])
        end

        def remove_seat_assignments(seats_to_remove)
          user_ids = seats_to_remove.keys

          GitlabSubscriptions::SeatAssignment.by_namespace_and_users(root_namespace, user_ids).delete_all
        end

        def seat_type_mappings(user_ids)
          GitlabSubscriptions::SeatTypeCalculator.bulk_execute(user_ids, root_namespace)
            .partition { |_k, v| v.nil? }.map(&:to_h)
        end

        def seat_assignment(user_id, seat_type)
          {
            namespace_id: root_namespace.id,
            user_id: user_id,
            seat_type: seat_type,
            organization_id: root_namespace.organization_id
          }
        end

        def user_namespace_error
          ServiceResponse.error(message: 'Seat assignments unavailable for user namespaces on GitLab.com')
        end
      end
    end
  end
end
