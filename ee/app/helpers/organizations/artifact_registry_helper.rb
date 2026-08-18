# frozen_string_literal: true

module Organizations
  module ArtifactRegistryHelper
    HTTP_ORIGIN_PATTERN = %r{\Ahttps?://\S+\z}

    def artifact_registry_repositories_app_data(organization, slug)
      {
        organization_gid: organization.to_global_id,
        slug: slug,
        base_path: artifact_registry_repositories_organization_path(organization, slug),
        client_base_url: artifact_registry_client_base_url
      }.to_json
    end

    def artifact_registry_setup_app_data(organization)
      {
        organization_gid: organization.to_global_id,
        organization_path: organization.path,
        client_base_url: artifact_registry_client_base_url
      }.to_json
    end

    private

    # The client URL and the management API share the Artifact Registry origin
    # ([ADR-009](https://gitlab.com/gitlab-org/ops/artifact-registry/-/blob/main/docs/adr/009_api_design.md)),
    # so only the origin of the configured `api_url` is reused; the paths differ. Read
    # through `[]` rather than `.api_url`: the key has no production default, and a
    # missing one raises on the reader while returning nil here.
    #
    # The guard does two jobs. `normalized_base_url` reflects whatever scheme it parsed,
    # so a well-formed `ftp://host` has to be rejected on the scheme; and it returns a
    # degenerate origin with nothing after the `://` for a scheme-less or hostless value.
    # Either way the browser gets nil, and the view leaves out the affordances that would
    # compose a URL from it.
    def artifact_registry_client_base_url
      base_url = ::Gitlab::UrlHelpers.normalized_base_url(Gitlab.config.artifact_registry['api_url'])

      base_url if base_url&.match?(HTTP_ORIGIN_PATTERN)
    end
  end
end
