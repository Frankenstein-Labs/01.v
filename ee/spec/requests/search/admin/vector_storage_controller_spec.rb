# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Admin::VectorStorageController, :enable_admin_mode, feature_category: :global_search do
  let_it_be(:admin, freeze: false) { create(:admin) }
  let_it_be(:user, freeze: false) { create(:user) }

  let(:semantic_search_redirect) { search_admin_application_settings_path(anchor: 'js-semantic-search-settings') }
  let(:vector_storage_path) { search_vector_storage_admin_application_settings_path }

  before do
    sign_in(admin)
  end

  shared_examples 'redirects logged-out users' do
    context 'for logged-out user' do
      before do
        sign_out(admin)
      end

      it 'redirects to login page' do
        send_request

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  shared_examples 'not available for non-admin users' do
    context 'for non-admin user' do
      before do
        sign_in(user)
      end

      it 'is not found' do
        send_request

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  describe 'GET #show' do
    subject(:send_request) { get vector_storage_path }

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    it 'renders successfully when no active connection exists', :aggregate_failures do
      send_request

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to include('data-testid="vector-storage-settings"')
      expect(response.body).not_to include('Semantic search is already configured')
      expect(response.body).not_to include('data-testid="vector-storage-reindex-warning"')
    end

    context 'when an invalid adapter param is submitted' do
      it 'renders successfully and defaults to Elasticsearch', :aggregate_failures do
        get vector_storage_path, params: { adapter: 'malicious' }

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('data-testid="elasticsearch-section"')
      end
    end

    context 'when an active connection exists' do
      before do
        create(:ai_active_context_connection)
      end

      it 'renders successfully' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when using advanced search config' do
      before do
        stub_licensed_features(elastic_search: true)
        allow(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?).and_return(true)
        create(:ai_active_context_connection, :elasticsearch, options: { 'use_advanced_search_config' => true })
      end

      it 'renders successfully' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'shows the info alert explaining how to configure a custom adapter', :aggregate_failures do
        send_request

        expect(response.body).to include('Semantic search is already configured')
        expect(response.body).to include('disable it and configure a custom adapter')
      end

      it 'shows the Advanced Search cluster section with In use badge', :aggregate_failures do
        send_request

        expect(response.body).to include('Advanced Search cluster')
        expect(response.body).to include('In use')
      end
    end

    context 'when using a custom connection' do
      before do
        stub_licensed_features(elastic_search: true)
        allow(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?).and_return(true)
        create(:ai_active_context_connection, options: { 'url' => 'http://es.example.com', 'username' => 'user' })
      end

      it 'renders successfully' do
        send_request

        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'shows the Custom connection heading' do
        send_request

        expect(response.body).to include('Custom connection')
      end

      it 'shows the info alert explaining how to switch to the Advanced Search cluster' do
        send_request

        expect(response.body).to include('Semantic search is already configured')
        expect(response.body).to include('disable it and switch to the Advanced Search cluster')
      end

      it 'shows the re-index warning' do
        send_request

        expect(response.body).to include('data-testid="vector-storage-reindex-warning"')
      end
    end

    context 'when elasticsearch_indexing? is disabled' do
      before do
        allow(Gitlab::CurrentSettings).to receive(:elasticsearch_indexing?).and_return(false)
      end

      it 'does not render the Advanced Search cluster section' do
        send_request

        expect(response.body).not_to include('Advanced Search cluster')
      end
    end

    context 'when elastic_search license is not available' do
      before do
        stub_licensed_features(elastic_search: false)
      end

      it 'does not render the Advanced Search cluster section' do
        send_request

        expect(response.body).not_to include('Advanced Search cluster')
      end
    end
  end

  describe 'POST #use_advanced_search_cluster_for_semantic_search' do
    subject(:send_request) { post admin_search_vector_storage_use_advanced_search_cluster_for_semantic_search_path }

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    it 'connects to advanced search cluster and redirects with a notice', :aggregate_failures do
      expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_advanced_search_cluster)

      send_request

      expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
      expect(response).to redirect_to semantic_search_redirect
    end

    context 'when a ConnectionError is raised' do
      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_advanced_search_cluster)
          .and_raise(Ai::ActiveContext::ConnectionService::ConnectionError, 'Connection invalid')
      end

      it 'sets an alert flash and redirects to the vector storage page', :aggregate_failures do
        send_request

        expect(flash[:alert]).to eq('Failed to connect: Connection invalid.')
        expect(response).to redirect_to vector_storage_path
      end
    end
  end

  describe 'POST #connect_custom_elasticsearch_vector_storage' do
    let(:url) { 'http://es.example.com:9200' }
    let(:username) { 'user' }
    let(:password) { 'pass' }

    subject(:send_request) do
      post admin_search_vector_storage_connect_custom_elasticsearch_vector_storage_path,
        params: { url: url, username: username, password: password }
    end

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    context 'when connection succeeds' do
      it 'calls the connection service and redirects with a notice', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_elasticsearch_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(url: url, username: username, password: password)
        end

        send_request

        expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
        expect(response).to redirect_to semantic_search_redirect
      end

      it 'passes blank values through for blank optional params', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_elasticsearch_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(url: url, username: '', password: '')
        end

        post admin_search_vector_storage_connect_custom_elasticsearch_vector_storage_path,
          params: { url: url, username: '', password: '' }

        expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
        expect(response).to redirect_to semantic_search_redirect
      end
    end

    context 'when a ConnectionError is raised' do
      let(:error_message) { 'Connection refused' }

      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_elasticsearch_cluster)
          .and_raise(Ai::ActiveContext::ConnectionService::ConnectionError, error_message)
      end

      it 'sets an alert flash and re-renders the show page', :aggregate_failures do
        send_request

        expect(flash[:alert]).to eq("Failed to connect: #{error_message}.")
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when an ActiveRecord::RecordInvalid error is raised' do
      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_elasticsearch_cluster)
          .and_raise(ActiveRecord::RecordInvalid.new(
            build(:ai_active_context_connection, :elasticsearch, options: { url: '' }).tap(&:valid?)
          ))
      end

      it 'sets an alert flash with the full error message and re-renders the show page', :aggregate_failures do
        post admin_search_vector_storage_connect_custom_elasticsearch_vector_storage_path, params: { url: '' }

        expect(flash[:alert]).to eq("Failed to connect: URL can't be blank.")
        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'POST #connect_custom_opensearch_vector_storage' do
    let(:url) { 'http://os.example.com:9200' }
    let(:username) { 'user' }
    let(:password) { 'pass' }

    subject(:send_request) do
      post admin_search_vector_storage_connect_custom_opensearch_vector_storage_path,
        params: { url: url, username: username, password: password }
    end

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    context 'when connection succeeds' do
      it 'calls the connection service and redirects with a notice', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_opensearch_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(url: url, username: username, password: password)
        end

        send_request

        expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
        expect(response).to redirect_to semantic_search_redirect
      end

      it 'passes blank values through for blank optional params', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_opensearch_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(url: url, username: '', password: '')
        end

        post admin_search_vector_storage_connect_custom_opensearch_vector_storage_path,
          params: { url: url, username: '', password: '' }

        expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
        expect(response).to redirect_to semantic_search_redirect
      end

      it 'forwards submitted params as-is to the service', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_opensearch_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(
            url: url, aws: '1', aws_region: 'us-east-1', aws_access_key: 'key', aws_secret_access_key: 'secret'
          )
        end

        post admin_search_vector_storage_connect_custom_opensearch_vector_storage_path,
          params: { url: url, aws: '1', aws_region: 'us-east-1', aws_access_key: 'key',
                    aws_secret_access_key: 'secret' }

        expect(response).to redirect_to semantic_search_redirect
      end
    end

    context 'when a ConnectionError is raised' do
      let(:error_message) { 'Connection refused' }

      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_opensearch_cluster)
          .and_raise(Ai::ActiveContext::ConnectionService::ConnectionError, error_message)
      end

      it 'sets an alert flash and re-renders the show page', :aggregate_failures do
        send_request

        expect(flash[:alert]).to eq("Failed to connect: #{error_message}.")
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'preserves the unchecked state of the aws checkbox' do
        post admin_search_vector_storage_connect_custom_opensearch_vector_storage_path,
          params: { url: url }

        expect(response.body).not_to include('checked="checked"')
      end

      it 'preserves the checked state of the aws checkbox' do
        post admin_search_vector_storage_connect_custom_opensearch_vector_storage_path,
          params: { url: url, aws: '1' }

        expect(response.body).to include('checked="checked"')
      end
    end

    context 'when an ActiveRecord::RecordInvalid error is raised' do
      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_opensearch_cluster)
          .and_raise(ActiveRecord::RecordInvalid.new(
            build(:ai_active_context_connection, :opensearch, options: { url: '' }).tap(&:valid?)
          ))
      end

      it 'sets an alert flash with the full error message and re-renders the show page', :aggregate_failures do
        post admin_search_vector_storage_connect_custom_opensearch_vector_storage_path, params: { url: '' }

        expect(flash[:alert]).to eq("Failed to connect: URL can't be blank.")
        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'POST #connect_custom_postgresql_vector_storage' do
    let(:host) { 'db.example.com' }
    let(:port) { '5432' }
    let(:database) { 'gitlabhq_production' }
    let(:db_user) { 'gitlab' }
    let(:password) { 'pass' }

    subject(:send_request) do
      post admin_search_vector_storage_connect_custom_postgresql_vector_storage_path,
        params: { host: host, port: port, database: database, user: db_user, password: password }
    end

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    context 'when connection succeeds' do
      it 'calls the connection service and redirects with a notice', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_postgresql_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(
            host: host, port: port, database: database, user: db_user, password: password
          )
        end

        send_request

        expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
        expect(response).to redirect_to semantic_search_redirect
      end

      it 'passes blank values through for blank optional params', :aggregate_failures do
        expect(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_postgresql_cluster) do |params|
          expect(params.to_h.symbolize_keys).to eq(
            host: host, port: '', database: database, user: '', password: ''
          )
        end

        post admin_search_vector_storage_connect_custom_postgresql_vector_storage_path,
          params: { host: host, port: '', database: database, user: '', password: '' }

        expect(flash[:notice]).to eq('Successfully connected. Indexing will start soon.')
        expect(response).to redirect_to semantic_search_redirect
      end
    end

    context 'when a ConnectionError is raised' do
      let(:error_message) { 'Connection refused' }

      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_postgresql_cluster)
          .and_raise(Ai::ActiveContext::ConnectionService::ConnectionError, error_message)
      end

      it 'sets an alert flash and re-renders the show page', :aggregate_failures do
        send_request

        expect(flash[:alert]).to eq("Failed to connect: #{error_message}.")
        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'when an ActiveRecord::RecordInvalid error is raised' do
      before do
        allow(Ai::ActiveContext::ConnectionService).to receive(:connect_to_custom_postgresql_cluster)
          .and_raise(ActiveRecord::RecordInvalid.new(
            build(:ai_active_context_connection, :postgresql).tap { |c| c.errors.add(:base, 'some error') }
          ))
      end

      it 'sets an alert flash with the full error message and re-renders the show page', :aggregate_failures do
        post admin_search_vector_storage_connect_custom_postgresql_vector_storage_path,
          params: { host: host, database: database }

        expect(flash[:alert]).to eq('Failed to connect: some error.')
        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'POST #disable_semantic_search' do
    subject(:send_request) { post admin_search_vector_storage_disable_semantic_search_path }

    it_behaves_like 'redirects logged-out users'
    it_behaves_like 'not available for non-admin users'

    it 'disables semantic search and redirects with a notice', :aggregate_failures do
      expect(Ai::ActiveContext::ConnectionService).to receive(:disable_connection)

      send_request

      expect(flash[:notice]).to eq('Semantic search will be disabled soon.')
      expect(response).to redirect_to semantic_search_redirect
    end
  end
end
