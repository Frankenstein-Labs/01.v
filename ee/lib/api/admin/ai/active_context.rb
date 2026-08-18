# frozen_string_literal: true

module API
  module Admin
    module Ai
      class ActiveContext < ::API::Base
        feature_category :global_search
        urgency :low

        before do
          authenticated_as_admin!
        end

        helpers do
          def find_connection!(id = nil)
            connection = ::Ai::ActiveContext::Connection.find_connection(id)
            not_found!('Connection') unless connection
            connection
          end

          def find_collection!(connection, id)
            collection = find_collection(connection, id)
            not_found!('Collection') unless collection
            collection
          end

          def find_enabled_namespace!(connection, namespace)
            enabled_namespace =
              ::Ai::ActiveContext::Code::EnabledNamespace.find_enabled_namespace(connection, namespace)
            not_found!('Enabled Namespace') unless enabled_namespace
            enabled_namespace
          end

          def resolve_queue!(name)
            queue_classes = ::ActiveContext::Config.queue_classes + [::ActiveContext::RetryQueue]
            queue_map = queue_classes.index_by(&:queue_name)
            queue_class = queue_map[name]
            bad_request!("Unknown queue '#{name}'. Valid queues: #{queue_map.keys.sort.join(', ')}") unless queue_class
            queue_class
          end

          def update_collection_queue_shard_count(collection, queue_shard_count)
            return unless queue_shard_count

            result = ::Ai::ActiveContext::UpdateQueueShardCountService.new(
              collection_class: collection.collection_class.constantize,
              queue_shard_count: queue_shard_count
            ).execute

            unprocessable_entity!("422 Unprocessable entity - #{result.message}") if result.error?
          end

          def update_collection_queue_shard_limit(collection, queue_shard_limit)
            return unless queue_shard_limit

            collection.reset.update_options!(queue_shard_limit: queue_shard_limit)
          end

          private

          def find_collection(connection, id)
            return unless id

            if ::API::Helpers::INTEGER_ID_REGEX.match?(id.to_s)
              ::Ai::ActiveContext::Collection.find_by_id(connection, id)
            else
              ::Ai::ActiveContext::Collection.find_by_name(connection, id)
            end
          end
        end

        resources 'admin/active_context/connections' do
          desc 'Get all ActiveContext connections' do
            success ::API::Entities::Ai::ActiveContext::Connection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' }
            ]
            tags %w[active_context]
          end
          route_setting :authorization, permissions: :read_active_context_connection, boundary_type: :instance
          get do
            present ::Ai::ActiveContext::Connection.all, with: ::API::Entities::Ai::ActiveContext::Connection
          end

          desc 'Activate an ActiveContext connection' do
            success ::API::Entities::Ai::ActiveContext::Connection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            requires :connection_id, type: Integer, desc: 'Connection ID'
          end
          route_setting :authorization, permissions: :update_active_context_connection, boundary_type: :instance
          put 'activate' do
            connection = find_connection!(params[:connection_id])

            connection.activate!

            present connection, with: ::API::Entities::Ai::ActiveContext::Connection
          end

          desc 'Deactivate an ActiveContext connection' do
            success ::API::Entities::Ai::ActiveContext::Connection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            optional :connection_id, type: Integer, desc: 'Connection ID (defaults to active connection)'
          end
          route_setting :authorization, permissions: :update_active_context_connection, boundary_type: :instance
          put 'deactivate' do
            connection = find_connection!(params[:connection_id])

            connection.deactivate!

            present connection, with: ::API::Entities::Ai::ActiveContext::Connection
          end
        end

        resources 'admin/active_context/collections' do
          desc 'Update collection options' do
            success ::API::Entities::Ai::ActiveContext::Collection
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' },
              { code: 422, message: '422 Unprocessable entity' }
            ]
            tags %w[active_context]
          end
          params do
            requires :id, types: [String, Integer], desc: 'Collection name or ID'
            at_least_one_of :queue_shard_count, :queue_shard_limit
            optional :queue_shard_count, type: Integer, desc: 'Number of queue shards'
            optional :queue_shard_limit, type: Integer, desc: 'Queue shard limit'
            optional :connection_id, type: Integer, desc: 'Connection ID (defaults to active connection)'
          end
          route_setting :authorization, permissions: :update_active_context_collection, boundary_type: :instance
          put ':id' do
            connection = find_connection!(params[:connection_id])
            collection = find_collection!(connection, params[:id])

            update_collection_queue_shard_count(collection, params[:queue_shard_count])
            update_collection_queue_shard_limit(collection, params[:queue_shard_limit])

            present collection.reset, with: ::API::Entities::Ai::ActiveContext::Collection
          end
        end

        resources 'admin/active_context/dead_queue' do
          desc 'Clear the ActiveContext dead queue' do
            success code: 200
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' }
            ]
            tags %w[active_context]
          end
          route_setting :authorization, permissions: :clear_active_context_dead_queue, boundary_type: :instance
          delete do
            size_before = ::ActiveContext::DeadQueue.queue_size
            ::ActiveContext::DeadQueue.clear_tracking!
            { cleared: size_before }
          end

          desc 'Replay items from the dead queue into another queue' do
            success code: 201
            failure [
              { code: 400, message: '400 Bad Request' },
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' }
            ]
            tags %w[active_context]
          end
          params do
            requires :queue, type: String, desc: 'Target queue name (e.g. retry_queue, code, code_backfill)'
          end
          route_setting :authorization, permissions: :replay_active_context_dead_queue, boundary_type: :instance
          post 'replay' do
            connection = find_connection!
            resolve_queue!(params[:queue])

            max_score = ::ActiveContext::Redis.with_redis do |redis|
              redis.get(::ActiveContext::DeadQueue.redis_score_key(0))&.to_f
            end

            if max_score
              task = ::Ai::ActiveContext::Task.create!(
                connection: connection,
                name: ::Ai::ActiveContext::Tasks::ReplayDeadQueue.name,
                status: :pending,
                params: { 'queue_name' => params[:queue], 'max_score' => max_score }
              )

              { enqueued: true, queue: params[:queue], task_id: task.id }
            else
              { enqueued: false, queue: params[:queue] }
            end
          end
        end

        resources 'admin/active_context/code/enabled_namespaces' do
          desc 'Update enabled namespace state' do
            success ::API::Entities::Ai::ActiveContext::Code::EnabledNamespace
            failure [
              { code: 401, message: '401 Unauthorized' },
              { code: 403, message: '403 Forbidden' },
              { code: 404, message: '404 Not found' }
            ]
            tags %w[active_context]
          end
          params do
            requires :namespace_id, types: [String, Integer], desc: 'Namespace path or ID'
            requires :state, type: String, values: %w[pending ready], desc: 'State (pending or ready)'
            optional :connection_id, type: Integer, desc: 'Connection ID (defaults to active connection)'
          end
          route_setting :authorization,
            permissions: :update_active_context_enabled_namespace, boundary_type: :instance
          put do
            connection = find_connection!(params[:connection_id])
            namespace = find_namespace!(params[:namespace_id])
            enabled_namespace = find_enabled_namespace!(connection, namespace)

            case params[:state]
            when 'pending'
              enabled_namespace.pending!
            when 'ready'
              enabled_namespace.ready!
            end

            present enabled_namespace, with: ::API::Entities::Ai::ActiveContext::Code::EnabledNamespace
          end
        end
      end
    end
  end
end
