# frozen_string_literal: true

module EE
  module Search
    module ProjectService
      extend ::Gitlab::Utils::Override
      include ::Search::AdvancedAndZoektSearchable

      SCOPES_THAT_SUPPORT_BRANCHES = %w[wiki_blobs commits blobs].freeze

      # project search always includes archived and forked projects
      override :zoekt_filters
      def zoekt_filters
        super.merge(include_archived: true, exclude_forks: false)
      end

      override :search_type
      def search_type
        use_default_branch? ? super : 'basic'
      end

      def elasticsearch_results
        search = params[:search]
        order_by = params[:order_by]
        sort = params[:sort]

        ::Search::Elastic::ProjectSearchResults.new(
          current_user,
          search,
          project: project,
          root_ancestor_ids: [project.root_ancestor.id],
          repository_ref: repository_ref,
          order_by: order_by,
          sort: sort,
          filters: filters
        )
      end

      def repository_ref
        params[:repository_ref]
      end

      def use_default_branch?
        return true if repository_ref.blank?
        return true unless SCOPES_THAT_SUPPORT_BRANCHES.include?(scope)

        project.root_ref?(repository_ref)
      end

      override :elasticsearchable_scope
      def elasticsearchable_scope
        project unless global_elasticsearchable_scope?
      end

      override :zoekt_searchable_scope
      def zoekt_searchable_scope
        project
      end

      def zoekt_project_id
        project.id
      end

      def zoekt_group_id; end

      override :search_level
      def search_level
        :project
      end

      override :zoekt_projects
      def zoekt_projects
        @zoekt_projects ||= ::Project.id_in(project)
      end

      override :zoekt_nodes
      def zoekt_nodes
        @zoekt_nodes ||= ::Search::Zoekt::Node.searchable_for_project(zoekt_searchable_scope)
      end
    end
  end
end
