# frozen_string_literal: true

module EE
  module Projects
    module BlobController
      extend ActiveSupport::Concern

      prepended do
        before_action do
          push_licensed_feature(:remote_development)
          push_frontend_feature_flag(:repository_lock_information, @project)
        end

        before_action only: [:show] do
          push_frontend_feature_flag(:orbit_code_intelligence, current_user)
          push_licensed_feature(:orbit, @project)
        end

        prepend_around_action :repair_blobs_index, only: [:show]
      end

      def visiting_from_search_page?
        return false if request.referer.blank?

        uri = URI.parse request.referer
        query_params = Rack::Utils.parse_query uri.query
        uri.present? && uri.path == search_path && query_params['scope'] == 'blobs'
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e)
        false
      end

      def repair_blobs_index
        yield
        return if @blob # We cannot use blob method as that is redirecting us in case of 404.

        return unless visiting_from_search_page?
        return unless project

        ::Search::ProjectIndexIntegrityWorker.perform_async(project.id, { force_repair_blobs: true })
      end
    end
  end
end
