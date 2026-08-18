# frozen_string_literal: true

module API
  module Admin
    class KnowledgeGraph < ::API::Base
      MAX_RESULTS = 20

      feature_category :knowledge_graph
      urgency :low

      helpers do
        def ensure_knowledge_graph_enabled!
          # Backend admin API for indexer namespace enrollment: gated on knowledge_graph_infra.
          return if Feature.enabled?(:knowledge_graph_infra, :instance)

          error!(
            'knowledge_graph_infra feature flag is not enabled', 400
          )
        end

        def ensure_orbit_enroll_namespace_enabled!(namespace)
          return if Feature.enabled?(:orbit_enroll_namespace, namespace)

          error!('orbit_enroll_namespace feature flag is not enabled', 400)
        end

        def ensure_orbit_licensed!
          forbidden! unless ::License.feature_available?(:orbit)
        end

        def ensure_root_namespace!(namespace)
          return if namespace.root?

          error!('Namespace must be a root namespace', 400)
        end
      end

      before do
        authenticated_as_admin!
        ensure_orbit_licensed!
      end

      namespace 'admin' do
        resources 'knowledge_graph/namespaces' do
          desc 'Get all enabled namespaces for Knowledge Graph' do
            detail 'This endpoint retrieves all namespaces that have Knowledge Graph enabled'
            success Entities::Analytics::KnowledgeGraph::EnabledNamespace
            failure [
              { code: 400, message: '400 Bad Request' },
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' }
            ]
            tags ['knowledge_graph']
          end
          route_setting :authorization,
            permissions: :read_knowledge_graph_enabled_namespace, boundary_type: :instance
          get do
            ensure_knowledge_graph_enabled!

            enabled_namespaces = ::Analytics::KnowledgeGraph::EnabledNamespace.recent.with_limit(MAX_RESULTS)

            present enabled_namespaces, with: Entities::Analytics::KnowledgeGraph::EnabledNamespace
          end

          desc 'Enable a namespace for Knowledge Graph' do
            detail 'This endpoint enables Knowledge Graph for a specific namespace'
            success Entities::Analytics::KnowledgeGraph::EnabledNamespace
            failure [
              { code: 400, message: '400 Bad Request' },
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags ['knowledge_graph']
          end
          params do
            requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the namespace'
          end
          route_setting :authorization,
            permissions: :create_knowledge_graph_enabled_namespace, boundary_type: :instance
          put ':id' do
            ensure_knowledge_graph_enabled!

            namespace = find_namespace!(params[:id])
            ensure_root_namespace!(namespace)
            ensure_orbit_enroll_namespace_enabled!(namespace)

            enabled_namespace = ::Analytics::KnowledgeGraph::EnabledNamespace
              .create_or_find_by(root_namespace_id: namespace.id) # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- only called from this API

            present enabled_namespace, with: Entities::Analytics::KnowledgeGraph::EnabledNamespace
          end

          desc 'Disable a namespace for Knowledge Graph' do
            detail 'This endpoint disables Knowledge Graph for a specific namespace'
            success code: 204
            failure [
              { code: 400, message: '400 Bad Request' },
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags ['knowledge_graph']
          end
          params do
            requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the namespace'
          end
          route_setting :authorization,
            permissions: :delete_knowledge_graph_enabled_namespace, boundary_type: :instance
          delete ':id' do
            ensure_knowledge_graph_enabled!

            namespace = find_namespace!(params[:id])
            ensure_root_namespace!(namespace)

            enabled_namespace = ::Analytics::KnowledgeGraph::EnabledNamespace
              .for_root_namespace_id(namespace.id)
              .first

            not_found!('Analytics::KnowledgeGraph::EnabledNamespace') unless enabled_namespace

            enabled_namespace.destroy!

            no_content!
          end
        end
      end
    end
  end
end
