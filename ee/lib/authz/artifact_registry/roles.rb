# frozen_string_literal: true

module Authz
  module ArtifactRegistry
    # Static mapping of Artifact Registry role names to their UUIDv7 identifiers.
    #
    # These ids are owned by the shared role-permissions library glaz-roles
    # (gitlab-org/auth/glaz: crates/glaz-roles/roles/artifact_registry/*.yml) and
    # mirrored in IAM. This static copy is interim: long term glaz-roles should be
    # the single source of truth and Rails should fetch the mapping rather than
    # hardcode it. Keep in sync with glaz-roles until then.
    module Roles
      ROLE_IDS = {
        artifact_viewer: '019ed9d4-7d53-7b5c-8653-1ceac0c48b14',
        artifact_contributor: '019ed9d4-7d52-7b6c-ad54-7798efc9bd5d',
        artifact_manager: '019ed9d4-7d52-7484-a3aa-aed918346651',
        artifact_admin: '019ed9d4-7d50-7249-9baa-52594d2d645b'
      }.freeze

      ROLE_NAMES = ROLE_IDS.invert.freeze

      def self.uuid_for(role_name)
        ROLE_IDS[role_name.downcase.to_sym]
      end

      def self.name_for(role_id)
        ROLE_NAMES[role_id]
      end
    end
  end
end
