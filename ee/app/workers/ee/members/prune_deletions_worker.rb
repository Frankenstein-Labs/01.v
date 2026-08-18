# frozen_string_literal: true

module EE
  module Members
    module PruneDeletionsWorker
      extend ::Gitlab::Utils::Override

      private

      override :destroy_member
      def destroy_member(member, member_deletion_schedule)
        scheduled_by = member_deletion_schedule.scheduled_by
        ip_address = member_deletion_schedule.ip_address.try(:to_s)

        ::Members::DestroyService.new(
          member,
          current_user: scheduled_by,
          skip_subresources: true,
          skip_saml_identity: true,
          ip_address: ip_address
        ).execute
      end
    end
  end
end
