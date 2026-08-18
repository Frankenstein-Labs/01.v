# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillExternalGroupAuditEventDestinations
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def perform
          # No-op: This module has been replaced by BackfillExternalGroupAuditEventDestinationsFixed
          # due to an issue with double JSON encoding: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/186866
        end
      end
    end
  end
end
