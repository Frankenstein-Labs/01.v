# frozen_string_literal: true

module EE
  module API
    module Releases
      extend ActiveSupport::Concern

      prepended do
        resource :projects, requirements: ::API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
          desc 'Generate release evidence' do
            detail 'Generates an evidence for an existing release.'
            success ::API::Entities::Release
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 404, message: 'Not found' }
            ]
            tags %w[releases]
          end
          params do
            requires :tag_name, type: String, desc: 'The Git tag the release is associated with', as: :tag
          end
          route_setting :authentication, job_token_allowed: true
          route_setting :authorization, job_token_policies: :admin_releases, permissions: :create_release_evidence,
            boundary_type: :project
          post ':id/releases/:tag_name/evidence', requirements: ::API::Releases::RELEASE_ENDPOINT_REQUIREMENTS do
            authorize_create_evidence!

            if release.present?
              params = { tag: release.tag }
              evidence_pipeline = ::Releases::EvidencePipelineFinder.new(release.project, params).execute
              ::Releases::CreateEvidenceWorker.perform_async(release.id, evidence_pipeline)

              status :accepted
            else
              status :not_found
            end
          end
        end

        helpers do
          extend ::Gitlab::Utils::Override

          override :authorize_create_evidence!
          def authorize_create_evidence!
            authorize_create_release!
          end
        end
      end
    end
  end
end
