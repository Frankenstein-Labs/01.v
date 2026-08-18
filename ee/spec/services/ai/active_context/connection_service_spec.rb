# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::ConnectionService, feature_category: :global_search do
  let(:elastic_helper) { instance_double(Search::Elastic::Helper) }

  before do
    allow(Search::Elastic::Helper).to receive(:default).and_return(elastic_helper)
  end

  describe '.connect_to_advanced_search_cluster' do
    context 'when distribution is opensearch' do
      before do
        allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(true)
        allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(false)
      end

      it 'creates an active opensearch connection with use_advanced_search_config option' do
        described_class.connect_to_advanced_search_cluster

        connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch_advanced_search')

        expect(connection).to be_present
        expect(connection.adapter_class).to eq('ActiveContext::Databases::Opensearch::Adapter')
        expect(connection.use_advanced_search_config_option).to be true
        expect(connection).to be_active
      end
    end

    context 'when distribution is elasticsearch' do
      before do
        allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
        allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(true)
      end

      it 'creates an active elasticsearch connection with use_advanced_search_config option' do
        described_class.connect_to_advanced_search_cluster

        connection = Ai::ActiveContext::Connection.find_by(name: 'elasticsearch_advanced_search')

        expect(connection).to be_present
        expect(connection.adapter_class).to eq('ActiveContext::Databases::Elasticsearch::Adapter')
        expect(connection.use_advanced_search_config_option).to be true
        expect(connection).to be_active
      end
    end

    context 'when distribution is neither opensearch nor elasticsearch' do
      before do
        allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
        allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(false)
      end

      it 'raises a ConnectionError and does not create a connection' do
        expect do
          described_class.connect_to_advanced_search_cluster
        end.to raise_error(described_class::ConnectionError, 'Connection invalid')
          .and not_change { Ai::ActiveContext::Connection.count }
      end
    end
  end

  describe '.connect_to_custom_elasticsearch_cluster' do
    let(:url) { 'https://example.com:9200' }
    let(:username) { 'elastic' }
    let(:password) { 'secret' }

    it 'creates an active connection with elasticsearch adapter and stores credentials' do
      described_class.connect_to_custom_elasticsearch_cluster(url: url, username: username, password: password)

      connection = Ai::ActiveContext::Connection.find_by(name: 'elasticsearch_custom')

      expect(connection).to be_present
      expect(connection.adapter_class).to eq('ActiveContext::Databases::Elasticsearch::Adapter')
      expect(connection).to be_active
      expect(connection.options['url']).to match_array([{ scheme: 'https', host: 'example.com', port: 9200,
                                                          path: '', user: 'elastic', password: 'secret' }])
      expect(connection.options['username']).to eq(username)
      expect(connection.options['password']).to eq(password)
    end

    it 'raises ActiveRecord::RecordInvalid when URL scheme is invalid' do
      expect do
        described_class.connect_to_custom_elasticsearch_cluster(url: 'ftp://es.example.com')
      end.to raise_error(ActiveRecord::RecordInvalid, /only supports valid HTTP/)
    end

    context 'when updating an active connection without re-submitting the URL' do
      it 'preserves the raw URL string in stored options' do
        active_connection = create(:ai_active_context_connection,
          name: 'elasticsearch_custom',
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { url: 'https://existing.example.com:9200' },
          active: true)

        described_class.connect_to_custom_elasticsearch_cluster(username: 'new_user')

        stored = active_connection.reload.read_attribute(:options)
        expect(stored['url']).to eq('https://existing.example.com:9200')
        expect(stored['url']).to be_a(String)
      end
    end

    context 'when clearing an optional field on an active connection' do
      it 'stores the empty string, effectively clearing the field' do
        active_connection = create(:ai_active_context_connection,
          name: 'elasticsearch_custom',
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { url: 'https://existing.example.com:9200', username: 'admin' },
          active: true)

        described_class.connect_to_custom_elasticsearch_cluster(url: 'https://existing.example.com:9200', username: '')

        expect(active_connection.reload.read_attribute(:options)['username']).to eq('')
      end
    end
  end

  describe '.connect_to_custom_opensearch_cluster' do
    let(:url) { 'https://example.com:9200' }
    let(:username) { 'admin' }
    let(:password) { 'secret' }

    it 'creates an active connection with opensearch adapter and stores credentials' do
      described_class.connect_to_custom_opensearch_cluster(url: url, username: username, password: password)

      connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch_custom')

      expect(connection).to be_present
      expect(connection.adapter_class).to eq('ActiveContext::Databases::Opensearch::Adapter')
      expect(connection).to be_active
      expect(connection.options['username']).to eq(username)
      expect(connection.options['password']).to eq(password)
    end

    it 'raises ActiveRecord::RecordInvalid when URL scheme is invalid' do
      expect do
        described_class.connect_to_custom_opensearch_cluster(url: 'ftp://os.example.com')
      end.to raise_error(ActiveRecord::RecordInvalid, /only supports valid HTTP/)
    end

    it 'stores AWS credentials when provided' do
      described_class.connect_to_custom_opensearch_cluster(
        url: url,
        aws: true,
        aws_region: 'us-east-1',
        aws_access_key: 'AKIA123',
        aws_secret_access_key: 'my_aws_secret',
        aws_role_arn: 'arn:aws:iam::123456789:role/GitLabSemanticSearch'
      )

      connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch_custom')
      opts = connection.stored_options

      expect(opts['aws']).to be(true)
      expect(opts['aws_region']).to eq('us-east-1')
      expect(opts['aws_access_key']).to eq('AKIA123')
      expect(opts['aws_secret_access_key']).to eq('my_aws_secret')
      expect(opts['aws_role_arn']).to eq('arn:aws:iam::123456789:role/GitLabSemanticSearch')
    end

    it 'converts aws string "1" to boolean true' do
      described_class.connect_to_custom_opensearch_cluster(url: url, aws: '1')

      connection = Ai::ActiveContext::Connection.find_by(name: 'opensearch_custom')
      expect(connection.stored_options['aws']).to be(true)
    end

    context 'when password is the mask value' do
      let_it_be(:existing_connection) do
        create(:ai_active_context_connection,
          name: 'opensearch_custom',
          adapter_class: 'ActiveContext::Databases::Opensearch::Adapter',
          options: { url: 'https://example.com:9200', password: 'real_secret' },
          active: true)
      end

      it 'preserves the existing password' do
        described_class.connect_to_custom_opensearch_cluster(
          url: url,
          password: Ai::ActiveContext::Connection::MASKED_PASSWORD
        )

        expect(existing_connection.reload.read_attribute(:options)['password']).to eq('real_secret')
      end
    end

    context 'when aws is submitted as "0" (unchecked checkbox)' do
      let_it_be(:existing_connection) do
        create(:ai_active_context_connection,
          name: 'opensearch_custom',
          adapter_class: 'ActiveContext::Databases::Opensearch::Adapter',
          options: { url: 'https://example.com:9200', aws: true, aws_region: 'us-east-1' },
          active: true)
      end

      it 'disables AWS on the active connection but preserves other AWS fields' do
        described_class.connect_to_custom_opensearch_cluster(url: url, aws: '0')

        opts = existing_connection.reload.stored_options
        expect(opts['aws']).to be(false)
        expect(opts['aws_region']).to eq('us-east-1')
      end
    end

    context 'when aws_secret_access_key is the mask value' do
      let_it_be(:existing_connection) do
        create(:ai_active_context_connection,
          name: 'opensearch_custom',
          adapter_class: 'ActiveContext::Databases::Opensearch::Adapter',
          options: { url: 'https://example.com:9200', aws_secret_access_key: 'real_aws_secret' },
          active: true)
      end

      it 'preserves the existing aws_secret_access_key' do
        described_class.connect_to_custom_opensearch_cluster(
          url: url,
          aws_secret_access_key: Ai::ActiveContext::Connection::MASKED_PASSWORD
        )

        expect(existing_connection.reload.read_attribute(:options)['aws_secret_access_key']).to eq('real_aws_secret')
      end
    end
  end

  describe '.connect_to_custom_postgresql_cluster' do
    let(:host) { 'db.example.com' }
    let(:port) { '5432' }
    let(:database) { 'gitlabhq_production' }
    let(:user) { 'gitlab' }
    let(:password) { 'secret' }

    it 'raises ActiveRecord::RecordInvalid when host is blank' do
      expect do
        described_class.connect_to_custom_postgresql_cluster(host: '', database: database)
      end.to raise_error(ActiveRecord::RecordInvalid, /host can't be blank/)
    end

    it 'creates an active connection with postgresql adapter and stores credentials' do
      described_class.connect_to_custom_postgresql_cluster(
        host: host, port: port, database: database, user: user, password: password
      )

      connection = Ai::ActiveContext::Connection.find_by(name: 'postgresql_custom')

      expect(connection).to be_present
      expect(connection.adapter_class).to eq('ActiveContext::Databases::Postgresql::Adapter')
      expect(connection).to be_active
      expect(connection.stored_options['host']).to eq(host)
      expect(connection.stored_options['port']).to eq(port)
      expect(connection.stored_options['database']).to eq(database)
      expect(connection.stored_options['user']).to eq(user)
      expect(connection.stored_options['password']).to eq(password)
    end

    it 'does not store nil values' do
      described_class.connect_to_custom_postgresql_cluster(host: host, database: database)

      connection = Ai::ActiveContext::Connection.find_by(name: 'postgresql_custom')
      stored = connection.stored_options

      expect(stored).not_to have_key('port')
      expect(stored).not_to have_key('user')
      expect(stored).not_to have_key('password')
    end

    context 'when updating an active connection without re-submitting the host' do
      it 'preserves the existing host in stored options' do
        active_connection = create(:ai_active_context_connection,
          name: 'postgresql_custom',
          adapter_class: 'ActiveContext::Databases::Postgresql::Adapter',
          options: { host: 'db.example.com', database: 'gitlabhq_production' },
          active: true)

        described_class.connect_to_custom_postgresql_cluster(user: 'new_user')

        expect(active_connection.reload.read_attribute(:options)['host']).to eq('db.example.com')
      end
    end

    context 'when clearing an optional field on an active connection' do
      it 'stores the empty string, effectively clearing the field' do
        active_connection = create(:ai_active_context_connection,
          name: 'postgresql_custom',
          adapter_class: 'ActiveContext::Databases::Postgresql::Adapter',
          options: { host: 'db.example.com', database: 'gitlabhq_production', user: 'admin' },
          active: true)

        described_class.connect_to_custom_postgresql_cluster(
          host: 'db.example.com', database: 'gitlabhq_production', user: ''
        )

        expect(active_connection.reload.read_attribute(:options)['user']).to eq('')
      end
    end

    context 'when password is the mask value' do
      let_it_be(:existing_connection) do
        create(:ai_active_context_connection,
          name: 'postgresql_custom',
          adapter_class: 'ActiveContext::Databases::Postgresql::Adapter',
          options: { host: 'db.example.com', database: 'gitlabhq_production', password: 'real_secret' },
          active: true)
      end

      it 'preserves the existing password' do
        described_class.connect_to_custom_postgresql_cluster(
          host: 'db.example.com',
          database: 'gitlabhq_production',
          password: Ai::ActiveContext::Connection::MASKED_PASSWORD
        )

        expect(existing_connection.reload.read_attribute(:options)['password']).to eq('real_secret')
      end
    end
  end

  describe 'switching between connection types' do
    let_it_be(:custom_url) { 'https://custom.example.com:9200' }

    before do
      allow(elastic_helper).to receive(:matching_distribution?).with(:opensearch).and_return(false)
      allow(elastic_helper).to receive(:matching_distribution?).with(:elasticsearch).and_return(true)
    end

    context 'when no previous connection with the same name exists' do
      it 'creates a new connection without deactivating any previous one' do
        expect { described_class.connect_to_custom_elasticsearch_cluster(url: custom_url) }
          .to change { Ai::ActiveContext::Connection.count }.by(1)
      end
    end

    context 'when an existing deactivated connection with the same name exists' do
      let_it_be_with_reload(:deactivated_connection) do
        create(:ai_active_context_connection,
          name: 'elasticsearch_custom',
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { url: 'https://old.example.com:9200', username: 'old_user' },
          active: false)
      end

      it 'reactivates the existing connection with the new options' do
        described_class.connect_to_custom_elasticsearch_cluster(url: custom_url, username: 'new_user')

        deactivated_connection.reload
        expect(deactivated_connection).to be_active
        expect(deactivated_connection.read_attribute(:options)['url']).to eq(custom_url)
        expect(deactivated_connection.read_attribute(:options)['username']).to eq('new_user')
      end

      it 'does not create a new connection' do
        expect { described_class.connect_to_custom_elasticsearch_cluster(url: custom_url) }
          .not_to change { Ai::ActiveContext::Connection.count }
      end
    end

    context 'when an existing active connection with the same name exists' do
      let_it_be(:existing_connection) do
        create(:ai_active_context_connection,
          name: 'elasticsearch_custom',
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { url: custom_url },
          active: true)
      end

      let(:new_username) { 'admin' }

      it 'updates the existing connection options in place' do
        described_class.connect_to_custom_elasticsearch_cluster(url: custom_url, username: new_username)

        expect(existing_connection.reload.read_attribute(:options)['username']).to eq(new_username)
      end

      it 'does not create a new connection' do
        expect { described_class.connect_to_custom_elasticsearch_cluster(url: custom_url, username: new_username) }
          .not_to change { Ai::ActiveContext::Connection.count }
      end

      it 'does not deactivate the existing connection' do
        expect(existing_connection).not_to receive(:deactivate!)

        described_class.connect_to_custom_elasticsearch_cluster(url: custom_url, username: new_username)
      end

      context 'when password is the mask value' do
        before do
          existing_connection.update!(options: { url: custom_url, password: 'secret' })
        end

        it 'preserves the existing password' do
          described_class.connect_to_custom_elasticsearch_cluster(
            url: custom_url,
            password: Ai::ActiveContext::Connection::MASKED_PASSWORD
          )

          expect(existing_connection.reload.read_attribute(:options)['password']).to eq('secret')
        end
      end
    end

    context 'when switching from Advanced Search to custom cluster' do
      let_it_be(:previous_connection) do
        create(:ai_active_context_connection,
          name: 'elasticsearch_advanced_search',
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { use_advanced_search_config: true },
          active: true)
      end

      it 'deactivates the previous connection and creates a new active one' do
        expect { described_class.connect_to_custom_elasticsearch_cluster(url: custom_url) }
          .to change { Ai::ActiveContext::Connection.count }.by(1)

        expect(Ai::ActiveContext::Connection.active.name).to eq('elasticsearch_custom')
        expect(previous_connection.reload).not_to be_active
      end

      it 'enqueues cleanup for the previous connection' do
        expect(Ai::ActiveContext::ConnectionCleanupWorker).to receive(:perform_async).with(previous_connection.id)

        described_class.connect_to_custom_elasticsearch_cluster(url: custom_url)

        expect(previous_connection.reload).not_to be_active
      end
    end

    context 'when switching from custom cluster to Advanced Search' do
      let_it_be(:previous_connection) do
        create(:ai_active_context_connection,
          name: 'elasticsearch_custom',
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { url: custom_url },
          active: true)
      end

      it 'deactivates the previous connection and enqueues its cleanup' do
        expect(Ai::ActiveContext::ConnectionCleanupWorker).to receive(:perform_async).with(previous_connection.id)

        described_class.connect_to_advanced_search_cluster

        expect(previous_connection.reload).not_to be_active
      end

      it 'creates a new active connection' do
        described_class.connect_to_advanced_search_cluster

        expect(Ai::ActiveContext::Connection.active).to be_present
        expect(Ai::ActiveContext::Connection.active).not_to eq(previous_connection)
      end
    end
  end

  describe '.disable_connection' do
    it 'schedules a DisableWorker job' do
      expect(Ai::ActiveContext::DisableWorker).to receive(:perform_in).with(1.minute)

      described_class.disable_connection
    end
  end
end
