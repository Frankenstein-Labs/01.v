# frozen_string_literal: true

module Organizations
  class ArtifactRegistryController < ApplicationController
    include ArtifactRegistryGating

    feature_category :artifact_registry

    # Registered after the gating concern's callback so the flag-off and missing-read-ability
    # refusals keep the response they already had. Every member holds the read ability, so the
    # update ability is the real gate on claiming a handle, which is what
    # `authorize_admin_organization!` checks despite its name.
    before_action :authorize_admin_organization!

    # The mount renders for any user who may update the organization. The
    # organization-to-namespace mapping that would narrow this to organizations without a
    # registry does not exist yet; once it does, an organization that has one no longer
    # reaches this page. See https://gitlab.com/gitlab-org/gitlab/-/work_items/603023.
    def index; end
  end
end
