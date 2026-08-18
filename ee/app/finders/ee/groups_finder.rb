# frozen_string_literal: true

module EE
  module GroupsFinder
    include Gitlab::Auth::Saml::SsoSessionFilterable
    extend ::Gitlab::Utils::Override

    private

    override :filter_groups
    def filter_groups(groups)
      groups = top_level_knowledge_graph_enabled_groups || groups
      groups = super(groups)
      groups = by_saml_sso_session(groups)
      groups = by_repository_storage(groups)
      by_knowledge_graph_enabled(groups)
    end

    def by_saml_sso_session(groups)
      filter_by_saml_sso_session(groups, :filter_expired_saml_session_groups)
    end

    def by_repository_storage(groups)
      return groups if params[:repository_storage].blank?

      groups.by_repository_storage(params[:repository_storage])
    end

    def by_knowledge_graph_enabled(groups)
      return groups unless params[:with_knowledge_graph_enabled]
      return groups if top_level_knowledge_graph_enabled_filter?
      return ::Group.none unless ::Feature.enabled?(:knowledge_graph, current_user)

      groups.with_knowledge_graph_enabled_namespace
    end

    def top_level_knowledge_graph_enabled_groups
      return unless top_level_knowledge_graph_enabled_filter?
      return ::Group.none unless ::Feature.enabled?(:knowledge_graph, current_user)

      ::Group
        .id_in(current_user.authorized_groups.roots.select(:id))
        .with_knowledge_graph_enabled_namespace
    end

    def top_level_knowledge_graph_enabled_filter?
      current_user &&
        params[:with_knowledge_graph_enabled] &&
        params[:top_level_only].present? &&
        !all_available? &&
        params[:owned].blank? &&
        params[:parent].blank? &&
        !min_access_level? &&
        params.fetch(:include_ancestors, true)
    end
  end
end
