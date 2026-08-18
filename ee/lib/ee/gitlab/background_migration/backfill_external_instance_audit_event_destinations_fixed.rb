# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillExternalInstanceAuditEventDestinationsFixed
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        def perform
          # No-op: This module has been replaced by FixIncompleteInstanceExternalAuditDestinations
          # due to an issue with double JSON encoding: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/189699
        end
      end
    end
  end
end
