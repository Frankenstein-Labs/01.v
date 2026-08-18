# frozen_string_literal: true

module Organizations
  class ArtifactRegistryRepositoriesController < ApplicationController
    include ArtifactRegistryGating

    feature_category :artifact_registry

    before_action :ensure_valid_slug!

    def index; end

    private

    def ensure_valid_slug!
      render_404 unless slug == ::Organizations::ArtifactRegistry::STUB_SLUG
    end

    def slug
      params.permit(:slug)[:slug]
    end
    helper_method :slug
  end
end
