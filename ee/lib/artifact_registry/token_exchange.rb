# frozen_string_literal: true

module ArtifactRegistry
  # Credential-acquisition seam for the Artifact Registry client.
  #
  # This is a stub: it returns nil until the real exchange is built. See the
  # auth design agreement for the intended mechanism:
  # https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/artifact_registry/agreements/auth/
  class TokenExchange
    def token_for(_current_user, _slug)
      nil
    end
  end
end
