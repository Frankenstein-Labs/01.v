# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Admin::Ai::ActiveContext, feature_category: :global_search do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:connection1) do
    create(:ai_active_context_connection, name: 'elastic', active: true,
      adapter_class: '::ActiveContext::Databases::Elasticsearch::Adapter')
  end

  let_it_be_with_reload(:connection2) do
    create(:ai_active_context_connection, name: 'postgres', active: false,
      adapter_class: '::ActiveContext::Databases::Postgresql::Adapter',
      options: { host: 'localhost' })
  end

  let_it_be_with_reload(:collection) do
    create(:ai_active_context_collection, :code_collection, connection: connection1)
  end

  let_it_be(:namespace) { create(:group) }
  let_it_be(:enabled_namespace) do
    create(:ai_active_context_code_enabled_namespace, namespace: namespace, active_context_connection: connection1)
  end

  shared_examples 'an API that returns 401 for unauthenticated requests' do |verb|
    it 'returns unauthorized status' do
      send(verb, api(path, nil))

      expect(response).to have_gitlab_http_status(:unauthorized)
    end
  end

  shared_examples 'an API that returns 403 for non-admin requests' do |verb|
    it 'returns forbidden status' do
      send(verb, api(path, user))

      expect(response).to have_gitlab_http_status(:forbidden)
    end
  end

  describe 'GET /admin/active_context/connections' do
    let(:path) { '/admin/active_context/connections' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :get
    it_behaves_like 'an API that returns 403 for non-admin requests', :get
    it_behaves_like 'authorizing granular token permissions', :read_active_context_connection do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { get api(path, personal_access_token: pat) }
    end

    it 'returns all connections' do
      get api(path, admin, admin_mode: true)

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to match_array([
        hash_including(
          'id' => connection1.id,
          'name' => 'elastic',
          'active' => true
        ),
        hash_including(
          'id' => connection2.id,
          'name' => 'postgres',
          'active' => false
        )
      ])
    end
  end

  describe 'PUT /admin/active_context/connections/activate' do
    let(:path) { '/admin/active_context/connections/activate' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put
    it_behaves_like 'authorizing granular token permissions', :update_active_context_connection do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { put api(path, personal_access_token: pat), params: { connection_id: connection2.id } }
    end

    it 'activates the specified connection' do
      put api(path, admin, admin_mode: true), params: { connection_id: connection2.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to include(
        'id' => connection2.id,
        'name' => 'postgres',
        'active' => true
      )

      expect(connection1.reload).not_to be_active
      expect(connection2.reload).to be_active
    end

    it 'does nothing if connection is already active' do
      put api(path, admin, admin_mode: true), params: { connection_id: connection1.id }

      expect(response).to have_gitlab_http_status(:ok)
      expect(json_response).to include(
        'id' => connection1.id,
        'active' => true
      )

      expect(connection1.reload).to be_active
    end

    it 'returns 404 for missing connection_id' do
      put api(path, admin, admin_mode: true),
        params: { connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1 }

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  describe 'PUT /admin/active_context/connections/deactivate' do
    let(:path) { '/admin/active_context/connections/deactivate' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put
    it_behaves_like 'authorizing granular token permissions', :update_active_context_connection do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { put api(path, personal_access_token: pat), params: { connection_id: connection1.id } }
    end

    context 'when connection_id is provided' do
      it 'deactivates the specified connection' do
        put api(path, admin, admin_mode: true), params: { connection_id: connection1.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => connection1.id,
          'name' => 'elastic',
          'active' => false
        )

        expect(connection1.reload).not_to be_active
      end

      it 'does nothing if connection is already inactive' do
        put api(path, admin, admin_mode: true), params: { connection_id: connection2.id }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => connection2.id,
          'active' => false
        )

        expect(connection2.reload).not_to be_active
      end

      it 'returns 404 for missing connection_id' do
        put api(path, admin, admin_mode: true),
          params: { connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1 }

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when connection_id is not provided' do
      it 'deactivates the currently active connection' do
        put api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => connection1.id,
          'name' => 'elastic',
          'active' => false
        )

        expect(connection1.reload).not_to be_active
      end

      context 'when no connection is active' do
        before do
          connection1.deactivate!
        end

        it 'returns 404' do
          put api(path, admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end

  describe 'PUT /admin/active_context/collections/:id' do
    before do
      allow(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new).and_call_original
    end

    let(:path) { "/admin/active_context/collections/#{collection.id}" }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put
    it_behaves_like 'authorizing granular token permissions', :update_active_context_collection do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { put api(path, personal_access_token: pat), params: { queue_shard_count: 32 } }
    end

    context 'when updating queue_shard_count only' do
      before do
        collection.update_options!(queue_shard_count: 16)
      end

      context 'when increasing the queue_shard_count' do
        it 'updates the collection options without creating tasks to drain orphaned shards' do
          expect(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new)

          expect do
            put api(path, admin, admin_mode: true), params: { queue_shard_count: 32 }
          end.not_to change { ::Ai::ActiveContext::Task.count }

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include(
            'id' => collection.id,
            'name' => collection.name,
            'connection_id' => connection1.id,
            'options' => hash_including('queue_shard_count' => 32)
          )

          expect(collection.reload.queue_shard_count).to eq(32)
        end
      end

      context 'when decreasing the queue_shard_count' do
        it 'updates the collection options and creates tasks to drain orphaned shards' do
          expect(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new)

          expect do
            put api(path, admin, admin_mode: true), params: { queue_shard_count: 8 }
          end.to change { ::Ai::ActiveContext::Task.count }.by(2)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to include(
            'id' => collection.id,
            'name' => collection.name,
            'connection_id' => connection1.id,
            'options' => hash_including('queue_shard_count' => 8)
          )

          expect(collection.reload.queue_shard_count).to eq(8)
        end
      end

      context 'when there is an error in the service response' do
        before do
          task_service = instance_double(::Ai::ActiveContext::UpdateQueueShardCountService, :execute)
          allow(task_service).to receive(:execute).and_return(
            ServiceResponse.error(message: "prerequisites not satisfied")
          )

          allow(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new).and_return(task_service)
        end

        it 'does not update the options and returns a 422' do
          expect(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new)

          expect do
            put api(path, admin, admin_mode: true), params: { queue_shard_count: 8 }
          end.not_to change { collection.reload.options }

          expect(json_response).to include(
            'message' => '422 Unprocessable entity - prerequisites not satisfied'
          )
        end
      end
    end

    context 'when updating queue_shard_limit only' do
      it 'updates the collection options' do
        expect(::Ai::ActiveContext::UpdateQueueShardCountService).not_to receive(:new)

        expect do
          put api(path, admin, admin_mode: true), params: { queue_shard_limit: 2000 }
        end.not_to change { ::Ai::ActiveContext::Task.count }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'connection_id' => connection1.id,
          'options' => hash_including('queue_shard_limit' => 2000)
        )

        expect(collection.reload.queue_shard_limit).to eq(2000)
      end
    end

    context 'when updating both options' do
      it 'updates both queue_shard_count and queue_shard_limit' do
        put api(path, admin, admin_mode: true), params: {
          queue_shard_count: 16,
          queue_shard_limit: 500
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'connection_id' => connection1.id,
          'options' => hash_including(
            'queue_shard_count' => 16,
            'queue_shard_limit' => 500
          )
        )

        collection.reload
        expect(collection.queue_shard_count).to eq(16)
        expect(collection.queue_shard_limit).to eq(500)
      end

      context 'when there is an error in the service response' do
        before do
          task_service = instance_double(::Ai::ActiveContext::UpdateQueueShardCountService, :execute)
          allow(task_service).to receive(:execute).and_return(
            ServiceResponse.error(message: "prerequisites not satisfied")
          )

          allow(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new).and_return(task_service)
        end

        it 'does not update the options and returns a bad request' do
          expect(::Ai::ActiveContext::UpdateQueueShardCountService).to receive(:new)

          expect do
            put(
              api(path, admin, admin_mode: true),
              params: { queue_shard_count: 8, queue_shard_limit: 500 }
            )
          end.not_to change { collection.reload.options }

          expect(json_response).to include(
            'message' => '422 Unprocessable entity - prerequisites not satisfied'
          )
        end
      end
    end

    context 'when finding collection by name' do
      let(:path) { "/admin/active_context/collections/#{collection.name}" }

      it 'updates the collection options' do
        put api(path, admin, admin_mode: true), params: { queue_shard_count: 24 }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'name' => collection.name,
          'options' => hash_including('queue_shard_count' => 24)
        )

        expect(collection.reload.queue_shard_count).to eq(24)
      end
    end

    context 'with specific connection_id' do
      it 'updates collection in specified connection' do
        put api(path, admin, admin_mode: true), params: {
          queue_shard_count: 8,
          connection_id: connection1.id
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => collection.id,
          'connection_id' => connection1.id,
          'options' => hash_including('queue_shard_count' => 8)
        )

        expect(collection.reload.queue_shard_count).to eq(8)
      end

      it 'returns 404 for collection in different connection' do
        put api(path, admin, admin_mode: true), params: {
          queue_shard_count: 8,
          connection_id: connection2.id
        }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Collection Not Found')
      end
    end

    it 'returns 404 for non-existent collection ID' do
      non_existent_id = Ai::ActiveContext::Collection.maximum(:id) + 1
      put api("/admin/active_context/collections/#{non_existent_id}", admin, admin_mode: true),
        params: { queue_shard_count: 8 }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Collection Not Found')
    end

    it 'returns 404 for non-existent collection name' do
      put api('/admin/active_context/collections/non_existent_collection', admin, admin_mode: true),
        params: { queue_shard_count: 8 }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Collection Not Found')
    end

    it 'returns 404 for non-existent connection' do
      put api(path, admin, admin_mode: true), params: {
        queue_shard_count: 8,
        connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1
      }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Connection Not Found')
    end

    it 'returns 400 when no options are provided' do
      put api(path, admin, admin_mode: true), params: {}

      expect(response).to have_gitlab_http_status(:bad_request)
    end

    context 'when preserving existing options' do
      before do
        collection.update_options!(queue_shard_count: 10, queue_shard_limit: 100)
      end

      it 'preserves existing options when updating only one' do
        put api(path, admin, admin_mode: true), params: { queue_shard_count: 20 }

        expect(response).to have_gitlab_http_status(:ok)

        collection.reload
        expect(collection.queue_shard_count).to eq(20)
        expect(collection.queue_shard_limit).to eq(100) # preserved
      end
    end
  end

  describe 'DELETE /admin/active_context/dead_queue' do
    let(:path) { '/admin/active_context/dead_queue' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :delete
    it_behaves_like 'an API that returns 403 for non-admin requests', :delete
    it_behaves_like 'authorizing granular token permissions', :clear_active_context_dead_queue do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { delete api(path, personal_access_token: pat) }
    end

    context 'when the dead queue has items' do
      before do
        allow(::ActiveContext::DeadQueue).to receive(:queue_size).and_return(42)
        allow(::ActiveContext::DeadQueue).to receive(:clear_tracking!)
      end

      it 'clears the dead queue and returns the count' do
        delete api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'cleared' => 42 })
        expect(::ActiveContext::DeadQueue).to have_received(:clear_tracking!)
      end
    end

    context 'when the dead queue is empty' do
      before do
        allow(::ActiveContext::DeadQueue).to receive(:queue_size).and_return(0)
        allow(::ActiveContext::DeadQueue).to receive(:clear_tracking!)
      end

      it 'returns cleared count of 0' do
        delete api(path, admin, admin_mode: true)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to eq({ 'cleared' => 0 })
      end
    end
  end

  describe 'POST /admin/active_context/dead_queue/replay' do
    let(:path) { '/admin/active_context/dead_queue/replay' }

    before do
      allow(::ActiveContext::Config).to receive(:queue_classes).and_return([])
    end

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :post
    it_behaves_like 'an API that returns 403 for non-admin requests', :post
    it_behaves_like 'authorizing granular token permissions', :replay_active_context_dead_queue do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) { post api(path, personal_access_token: pat), params: { queue: 'retry_queue' } }
    end

    context 'when the dead queue has items' do
      before do
        allow(::ActiveContext::Redis).to receive(:with_redis).and_yield(
          instance_double(Redis, get: '42.0')
        )
      end

      it 'creates a ReplayDeadQueue task and returns enqueued: true' do
        expect { post api(path, admin, admin_mode: true), params: { queue: 'retry_queue' } }
          .to change { ::Ai::ActiveContext::Task.count }.by(1)

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include('enqueued' => true, 'queue' => 'retry_queue')
        expect(json_response['task_id']).to be_present

        task = ::Ai::ActiveContext::Task.last
        expect(task.name).to eq('Ai::ActiveContext::Tasks::ReplayDeadQueue')
        expect(task.params).to include('queue_name' => 'retry_queue', 'max_score' => 42.0)
        expect(task.connection).to eq(connection1)
      end
    end

    context 'when the dead queue is empty' do
      before do
        allow(::ActiveContext::Redis).to receive(:with_redis).and_yield(
          instance_double(Redis, get: nil)
        )
      end

      it 'does not create a task and returns enqueued: false' do
        expect { post api(path, admin, admin_mode: true), params: { queue: 'retry_queue' } }
          .not_to change { ::Ai::ActiveContext::Task.count }

        expect(response).to have_gitlab_http_status(:created)
        expect(json_response).to include('enqueued' => false, 'queue' => 'retry_queue')
      end
    end

    context 'when an unknown queue name is provided' do
      it 'returns 400 with a helpful error message' do
        post api(path, admin, admin_mode: true), params: { queue: 'nonexistent_queue' }

        expect(response).to have_gitlab_http_status(:bad_request)
        expect(json_response['message']).to include("Unknown queue 'nonexistent_queue'")
        expect(json_response['message']).to include('retry_queue')
      end
    end

    context 'when queue param is missing' do
      it 'returns 400' do
        post api(path, admin, admin_mode: true), params: {}

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'PUT /admin/active_context/code/enabled_namespaces' do
    let(:path) { '/admin/active_context/code/enabled_namespaces' }

    it_behaves_like 'an API that returns 401 for unauthenticated requests', :put
    it_behaves_like 'an API that returns 403 for non-admin requests', :put
    it_behaves_like 'authorizing granular token permissions', :update_active_context_enabled_namespace do
      let(:boundary_object) { :instance }
      let(:user) { admin }
      let(:request) do
        put api(path, personal_access_token: pat), params: { namespace_id: namespace.id, state: 'ready' }
      end
    end

    context 'when finding namespace by path' do
      it 'updates enabled namespace state to ready' do
        put api(path, admin, admin_mode: true), params: { namespace_id: namespace.full_path, state: 'ready' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'ready'
        )

        expect(enabled_namespace.reload).to be_ready
      end

      it 'updates enabled namespace state to pending' do
        put api(path, admin, admin_mode: true), params: { namespace_id: namespace.full_path, state: 'pending' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'pending'
        )

        expect(enabled_namespace.reload).to be_pending
      end
    end

    context 'when finding namespace by ID' do
      it 'updates enabled namespace state' do
        put api(path, admin, admin_mode: true), params: { namespace_id: namespace.id, state: 'ready' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'ready'
        )

        expect(enabled_namespace.reload).to be_ready
      end
    end

    context 'with specific connection_id' do
      it 'updates enabled namespace in specified connection' do
        put api(path, admin, admin_mode: true), params: {
          namespace_id: namespace.full_path,
          state: 'ready',
          connection_id: connection1.id
        }

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response).to include(
          'id' => enabled_namespace.id,
          'namespace_id' => namespace.id,
          'state' => 'ready'
        )

        expect(enabled_namespace.reload).to be_ready
      end

      it 'returns 404 for invalid connection' do
        put api(path, admin, admin_mode: true), params: {
          namespace_id: namespace.full_path,
          state: 'ready',
          connection_id: connection2.id
        }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 Enabled Namespace Not Found')
      end
    end

    it 'returns 404 for non-existent namespace' do
      put api(path, admin, admin_mode: true), params: { namespace_id: 'non/existent/namespace', state: 'ready' }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Namespace Not Found')
    end

    it 'returns 404 for non-existent connection' do
      put api(path, admin, admin_mode: true), params: {
        namespace_id: namespace.full_path,
        state: 'ready',
        connection_id: Ai::ActiveContext::Connection.maximum(:id) + 1
      }

      expect(response).to have_gitlab_http_status(:not_found)
      expect(json_response['message']).to eq('404 Connection Not Found')
    end

    it 'returns 400 for invalid state' do
      put api(path, admin, admin_mode: true), params: { namespace_id: namespace.full_path, state: 'invalid_state' }

      expect(response).to have_gitlab_http_status(:bad_request)
    end
  end
end
