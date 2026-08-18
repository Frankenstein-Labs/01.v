# frozen_string_literal: true

module Organizations
  module ArtifactRegistry
    # Placeholder slug the repositories controller validates against (by
    # equality) before rendering the mount. Real slug discovery against the
    # organization's namespaces replaces this equality check later; see
    # https://gitlab.com/gitlab-org/gitlab/-/work_items/602638.
    STUB_SLUG = 'acme'
  end
end
