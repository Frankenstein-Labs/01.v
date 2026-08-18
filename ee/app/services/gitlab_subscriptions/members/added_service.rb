# frozen_string_literal: true

module GitlabSubscriptions
  module Members
    class AddedService
      BATCH_SIZE = 100

      def initialize(source, invited_user_ids)
        @source = source
        @invited_user_ids = invited_user_ids.compact
      end

      def execute
        return ServiceResponse.error(message: 'Invalid params') unless source&.root_ancestor

        recently_added_members_user_ids.each_slice(BATCH_SIZE) do |user_ids|
          seat_types = GitlabSubscriptions::SeatTypeCalculator.bulk_execute(user_ids, source.root_ancestor)
          seat_assignments = user_ids.map { |user_id| seat_assignment(user_id, seat_types[user_id]) }

          GitlabSubscriptions::SeatAssignment.upsert_all(seat_assignments, unique_by: [:namespace_id, :user_id])
        end

        ServiceResponse.success(message: 'Member added activity tracked')
      end

      private

      attr_reader :source, :invited_user_ids

      def recently_added_members_user_ids
        source.members.connected_to_user.including_user_ids(invited_user_ids).pluck_user_ids
      end

      def namespace_id
        source.root_ancestor.id
      end

      def organization_id
        source.root_ancestor.organization_id
      end

      def seat_assignment(user_id, seat_type)
        {
          namespace_id: namespace_id,
          organization_id: organization_id,
          user_id: user_id,
          seat_type: seat_type
        }
      end
    end
  end
end
