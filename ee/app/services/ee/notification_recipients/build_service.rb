# frozen_string_literal: true

#
# Used by NotificationService to determine who should receive notification
#
module EE
  module NotificationRecipients # rubocop:disable Gitlab/BoundedContexts -- Existing module structure
    module BuildService
      def self.build_service_account_recipients(...)
        ::NotificationRecipients::Builder::ServiceAccount.new(...).notification_recipients.map(&:user)
      end
    end
  end
end
