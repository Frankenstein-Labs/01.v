# frozen_string_literal: true

module Gitlab
  module EventStore
    module Subscriptions
      class PackageMetadataSubscriptions < BaseSubscriptions
        def register
          store.subscribe ::PackageMetadata::GlobalAdvisoryScanWorker, to: ::PackageMetadata::IngestedAdvisoryEvent
        end
      end
    end
  end
end
