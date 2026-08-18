# frozen_string_literal: true

module EE
  module Members
    module MembershipLockValidation
      extend ::Gitlab::Utils::Override

      private

      def membership_locked?(source)
        source.membership_locked?
      end
    end
  end
end
