# frozen_string_literal: true

module Organizations
  module Settings
    class ArtifactRegistryController < ::Organizations::ApplicationController
      include ArtifactRegistryGating

      feature_category :artifact_registry

      # Registered after the gating concern's callback so the flag-off and missing-read-ability
      # refusals keep the response they already had. Every member holds the read ability, so the
      # update ability is the real gate on the settings page, which is what
      # `authorize_admin_organization!` checks despite its name.
      before_action :authorize_admin_organization!

      def show; end
    end
  end
end
