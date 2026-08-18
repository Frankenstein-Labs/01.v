# frozen_string_literal: true

module Analytics
  module Orbit
    module TargetResolver
      def resolve_graph_status_context(params)
        target = find_graph_status_target(params)
        return unless target

        build_graph_status_context(target)
      end

      private

      def find_graph_status_target(params)
        namespace_id = params[:namespace_id]
        project_id = params[:project_id]
        full_path = params[:full_path]

        if namespace_id
          Group.find_by_id(namespace_id)
        elsif project_id
          Project.find_by_id(project_id)
        elsif full_path
          Routable.find_by_full_path(full_path)
        end
      end

      def build_graph_status_context(target)
        case target
        when Group
          { target: target, traversal_path: target.traversal_path(with_organization: true) }
        when Project
          return unless target.namespace.is_a?(Group)

          { target: target, traversal_path: target.project_namespace.traversal_path(with_organization: true) }
        end
      end
    end
  end
end
