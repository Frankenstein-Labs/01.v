# frozen_string_literal: true

module EE
  module Users
    module BannedUser
      extend ActiveSupport::Concern

      prepended do
        after_commit :reindex_issues_and_merge_requests, on: [:create, :destroy]
      end

      private

      def reindex_issues_and_merge_requests
        ElasticAssociationIndexerWorker.perform_async(user.class.name, user.id, %i[issues merge_requests])
      end
    end
  end
end
