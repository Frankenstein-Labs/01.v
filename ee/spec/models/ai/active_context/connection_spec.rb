# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Connection, feature_category: :global_search do
  it_behaves_like 'it has loose foreign keys' do
    let(:factory_name) { :ai_active_context_connection }
  end

  describe 'associations' do
    it { is_expected.to have_many(:migrations).class_name('Ai::ActiveContext::Migration') }
    it { is_expected.to have_many(:tasks).class_name('Ai::ActiveContext::Task') }
  end

  describe 'validations' do
    subject { build(:ai_active_context_connection) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:adapter_class) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:adapter_class).is_at_most(255) }
    it { is_expected.to validate_length_of(:prefix).is_at_most(255) }

    describe 'URL presence validation' do
      context 'when URL is blank' do
        it 'is invalid and adds error to base when url is nil' do
          connection = build(:ai_active_context_connection, :elasticsearch, options: { url: nil })

          expect(connection).not_to be_valid
          expect(connection.errors[:base]).to include("URL can't be blank")
        end
      end

      context 'when URL is present' do
        it 'is valid' do
          connection = build(:ai_active_context_connection, :elasticsearch,
            options: { url: 'http://es.example.com:9200' })

          expect(connection).to be_valid
        end
      end

      context 'when use_advanced_search_config is true' do
        it 'skips URL presence validation' do
          connection = build(:ai_active_context_connection, :elasticsearch,
            options: { use_advanced_search_config: true })

          connection.valid?

          expect(connection.errors[:base]).not_to include("URL can't be blank")
        end
      end

      context 'when the adapter is not elasticsearch-compatible' do
        it 'skips URL presence validation' do
          connection = build(:ai_active_context_connection, :postgresql)

          connection.valid?

          expect(connection.errors[:base]).not_to include("URL can't be blank")
        end
      end
    end

    describe 'URL scheme validation' do
      it 'validates the URL scheme for elasticsearch-compatible adapters' do
        connection = build(:ai_active_context_connection, :elasticsearch,
          options: { url: 'http://es.example.com:9200' })

        expect(::EE::Search::ElasticsearchUrl).to receive(:validate!)

        connection.valid?
      end

      context 'when the URL scheme is invalid' do
        before do
          allow(::EE::Search::ElasticsearchUrl).to receive(:validate!)
            .and_raise(::Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError)
        end

        it 'adds error to base' do
          connection = build(:ai_active_context_connection, :elasticsearch,
            options: { url: 'ftp://es.example.com:9200' })

          connection.valid?

          expect(connection.errors[:base]).to include("only supports valid HTTP(S) URLs")
        end
      end

      context 'when use_advanced_search_config is true' do
        it 'skips URL scheme validation' do
          connection = build(:ai_active_context_connection, :elasticsearch,
            options: { use_advanced_search_config: true })

          expect(::EE::Search::ElasticsearchUrl).not_to receive(:validate!)

          connection.valid?
        end
      end

      context 'when the adapter is not elasticsearch-compatible' do
        it 'skips URL scheme validation' do
          connection = build(:ai_active_context_connection, :postgresql)

          expect(::EE::Search::ElasticsearchUrl).not_to receive(:validate!)

          connection.valid?
        end
      end
    end

    describe 'PostgreSQL host validation' do
      context 'when host is blank' do
        it 'is invalid and adds error to base when host is empty string' do
          connection = build(:ai_active_context_connection, :postgresql,
            options: { host: '', database: 'postgres' })

          expect(connection).not_to be_valid
          expect(connection.errors[:base]).to include("host can't be blank")
        end

        it 'is invalid and adds error to base when host is nil' do
          connection = build(:ai_active_context_connection, :postgresql,
            options: { host: nil, database: 'postgres' })

          expect(connection).not_to be_valid
          expect(connection.errors[:base]).to include("host can't be blank")
        end
      end

      context 'when host is present' do
        it 'is valid' do
          connection = build(:ai_active_context_connection, :postgresql,
            options: { host: '127.0.0.1', database: 'postgres' })

          expect(connection).to be_valid
        end
      end

      context 'when the adapter is not postgresql' do
        it 'skips host validation' do
          connection = build(:ai_active_context_connection, :elasticsearch,
            options: { url: 'http://es.example.com' })

          connection.valid?

          expect(connection.errors[:base]).not_to include("host can't be blank")
        end
      end
    end
  end

  describe 'encryption' do
    let_it_be(:connection) { create(:ai_active_context_connection) }

    it 'encrypts options' do
      saved_connection = described_class.find(connection.id)

      # The encrypted value should be different from the original
      expect(saved_connection.options['token']).to eq(connection.options['token'])
      expect(saved_connection.attributes['options']).not_to include(connection.options['token'])
    end
  end

  describe '.active' do
    let_it_be(:active_connection) { create(:ai_active_context_connection) }
    let_it_be(:inactive_connection) { create(:ai_active_context_connection, :inactive) }

    it 'returns only active connection' do
      expect(described_class.active).to eq(active_connection)
    end
  end

  describe '#use_advanced_search_config_option' do
    context 'when use_advanced_search_config is true' do
      let(:connection) do
        build(:ai_active_context_connection, options: { use_advanced_search_config: true })
      end

      it 'returns true' do
        expect(connection.use_advanced_search_config_option).to be true
      end
    end

    context 'when use_advanced_search_config is false' do
      let(:connection) do
        build(:ai_active_context_connection, options: { use_advanced_search_config: false })
      end

      it 'returns false' do
        expect(connection.use_advanced_search_config_option).to be false
      end
    end

    context 'when use_advanced_search_config is not present' do
      let(:connection) do
        build(:ai_active_context_connection, options: { url: 'http://custom:9200' })
      end

      it 'returns nil' do
        expect(connection.use_advanced_search_config_option).to be_nil
      end
    end
  end

  describe '#adapter_name' do
    context 'when adapter is elasticsearch' do
      let(:connection) { build(:ai_active_context_connection, :elasticsearch) }

      it 'returns "elasticsearch"' do
        expect(connection.adapter_name).to eq('elasticsearch')
      end
    end

    context 'when adapter is opensearch' do
      let(:connection) { build(:ai_active_context_connection, :opensearch) }

      it 'returns "opensearch"' do
        expect(connection.adapter_name).to eq('opensearch')
      end
    end

    context 'when adapter is postgresql' do
      let(:connection) { build(:ai_active_context_connection, :postgresql) }

      it 'returns "postgresql"' do
        expect(connection.adapter_name).to eq('postgresql')
      end
    end

    context 'when adapter class is unknown' do
      let(:connection) { build(:ai_active_context_connection) }

      it 'returns nil' do
        expect(connection.adapter_name).to be_nil
      end
    end
  end

  describe '#options' do
    context 'when use_advanced_search_config is true for elasticsearch adapter' do
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          options: { use_advanced_search_config: true })
      end

      let(:gitlab_elasticsearch_config) do
        {
          url: [{ scheme: 'http', host: '127.0.0.1', port: 9200, path: '' }],
          aws: false,
          client_request_timeout: 30,
          retry_on_failure: 3
        }
      end

      before do
        allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_config).and_return(gitlab_elasticsearch_config)
      end

      it 'returns GitLab elasticsearch config directly' do
        expect(connection.options).to eq(gitlab_elasticsearch_config)
      end
    end

    context 'when use_advanced_search_config is false' do
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          prefix: nil,
          options: { url: 'http://custom:9200', username: 'user', password: 'pass', use_advanced_search_config: false })
      end

      it 'returns options with embedded credentials in url' do
        expect(connection.options['url']).to match_array([{
          scheme: 'http', host: 'custom', port: 9200, user: 'user', password: 'pass', path: ''
        }])
      end
    end

    context 'when adapter is not elasticsearch' do
      let(:custom_options) { { token: 'secret', use_advanced_search_config: true } }
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'SomeOtherAdapter',
          prefix: nil,
          options: custom_options)
      end

      it 'returns the stored options' do
        expect(connection.options).to eq(custom_options.stringify_keys)
      end
    end

    context 'when use_advanced_search_config is not present' do
      let(:connection) do
        build(:ai_active_context_connection,
          adapter_class: 'ActiveContext::Databases::Elasticsearch::Adapter',
          prefix: nil,
          options: { url: 'http://custom:9200' })
      end

      it 'returns options with url as credentials hash array' do
        expect(connection.options['url']).to match_array([{ scheme: 'http', host: 'custom', port: 9200, path: '' }])
      end
    end
  end

  describe '#adapter' do
    let_it_be(:connection) { create(:ai_active_context_connection) }
    let(:mock_adapter) { instance_double(::ActiveContext::Databases::Elasticsearch::Adapter) }

    before do
      allow(::ActiveContext::Adapter).to receive(:for_connection).and_return(mock_adapter)
    end

    it 'returns the adapter for the connection' do
      expect(connection.adapter).to eq(mock_adapter)
    end

    context 'when adapter is not available' do
      before do
        allow(::ActiveContext::Adapter).to receive(:for_connection).and_return(nil)
      end

      it 'returns nil' do
        expect(connection.adapter).to be_nil
      end
    end
  end

  describe '#activate!' do
    let_it_be_with_reload(:active_connection) { create(:ai_active_context_connection) }
    let_it_be_with_reload(:inactive_connection) { create(:ai_active_context_connection, :inactive) }

    context 'when the connection is already active' do
      it 'does not make any changes' do
        expect { active_connection.activate! }.not_to change { Ai::ActiveContext::Connection.active }
      end
    end

    context 'when the connection is inactive' do
      it 'activates the connection and deactivates the previously active connection' do
        expect do
          inactive_connection.activate!
        end.to change { Ai::ActiveContext::Connection.active }.from(active_connection).to(inactive_connection)

        expect(active_connection.reload).not_to be_active
        expect(inactive_connection.reload).to be_active
      end
    end

    context 'when an error occurs during activation' do
      before do
        allow(inactive_connection).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      end

      it 'rolls back the transaction and does not change the active connection' do
        expect do
          expect { inactive_connection.activate! }.to raise_error(ActiveRecord::RecordInvalid)
        end.not_to change { Ai::ActiveContext::Connection.active }

        expect(active_connection.reload).to be_active
        expect(inactive_connection.reload).not_to be_active
      end
    end
  end

  describe '#deactivate!' do
    let_it_be_with_reload(:connection) { create(:ai_active_context_connection) }
    let_it_be_with_reload(:inactive_connection) { create(:ai_active_context_connection, :inactive) }

    context 'when the connection is already inactive' do
      it 'does not make any changes' do
        expect { inactive_connection.deactivate! }.not_to change { inactive_connection.reload.active }
      end
    end

    context 'when the connection is active' do
      it 'deactivates the connection' do
        expect { connection.deactivate! }.to change { connection.reload.active }.from(true).to(false)
      end

      it 'enqueues ConnectionCleanupWorker after commit' do
        expect(Ai::ActiveContext::ConnectionCleanupWorker).to receive(:perform_async).with(connection.id)
        connection.deactivate!
      end
    end

    context 'when deactivating and activating another connection' do
      it 'enqueues ConnectionCleanupWorker for the old connection' do
        expect(Ai::ActiveContext::ConnectionCleanupWorker).to receive(:perform_async).with(connection.id)
        inactive_connection.activate!
      end
    end
  end

  describe '#masked_stored_options' do
    let(:connection) do
      build(:ai_active_context_connection, options: {
        url: 'http://localhost:9200',
        username: 'elastic',
        password: 'secret',
        aws_secret_access_key: 'aws-secret'
      })
    end

    it 'masks secret fields and preserves others', :aggregate_failures do
      result = connection.masked_stored_options

      expect(result['password']).to eq(described_class::MASKED_PASSWORD)
      expect(result['aws_secret_access_key']).to eq(described_class::MASKED_PASSWORD)
      expect(result).to include('url' => 'http://localhost:9200', 'username' => 'elastic')
    end

    context 'when secret fields are absent' do
      let(:connection) { build(:ai_active_context_connection, options: { url: 'http://localhost:9200' }) }

      it 'does not add absent secret keys', :aggregate_failures do
        result = connection.masked_stored_options

        expect(result).not_to have_key('password')
        expect(result).not_to have_key('aws_secret_access_key')
      end
    end

    context 'when a secret field is explicitly nil' do
      let(:connection) do
        build(:ai_active_context_connection, options: { url: 'http://localhost:9200', password: nil })
      end

      it 'does not include the key in the result' do
        expect(connection.masked_stored_options).not_to have_key('password')
      end
    end

    context 'when a secret field is an empty string' do
      let(:connection) do
        build(:ai_active_context_connection, options: { url: 'http://localhost:9200', password: '' })
      end

      it 'does not include the key in the result' do
        expect(connection.masked_stored_options).not_to have_key('password')
      end
    end
  end

  describe '#update_options!' do
    let_it_be_with_reload(:connection) do
      create(:ai_active_context_connection, options: {
        url: 'http://localhost:9200',
        username: 'elastic',
        password: 'secret',
        aws_secret_access_key: 'aws-secret'
      })
    end

    it 'merges a plain (non-secret) field over stored options' do
      connection.update_options!('username' => 'new_user')

      expect(connection.stored_options).to include('username' => 'new_user', 'url' => 'http://localhost:9200')
    end

    it 'preserves stored secrets when the masked placeholder is submitted' do
      connection.update_options!('password' => described_class::MASKED_PASSWORD)

      expect(connection.stored_options['password']).to eq('secret')
    end

    it 'preserves aws_secret_access_key when the masked placeholder is submitted' do
      connection.update_options!('aws_secret_access_key' => described_class::MASKED_PASSWORD)

      expect(connection.stored_options['aws_secret_access_key']).to eq('aws-secret')
    end

    it 'overwrites stored secrets when a real value is submitted' do
      connection.update_options!('password' => 'new_secret')

      expect(connection.stored_options['password']).to eq('new_secret')
    end

    it 'ignores masked placeholders while applying other updates in the same call', :aggregate_failures do
      connection.update_options!('password' => described_class::MASKED_PASSWORD, 'username' => 'updated')

      expect(connection.stored_options['password']).to eq('secret')
      expect(connection.stored_options['username']).to eq('updated')
    end

    it 'clears a stored secret when an empty string is submitted' do
      connection.update_options!('password' => '')

      expect(connection.stored_options['password']).to eq('')
    end

    it 'stores nil for a key when nil is submitted' do
      connection.update_options!('password' => nil)

      expect(connection.stored_options['password']).to be_nil
    end
  end

  describe '#reload_adapter' do
    let(:connection) { create(:ai_active_context_connection) }

    it 'clears the cached adapter instance' do
      mock_adapter = instance_double(::ActiveContext::Databases::Elasticsearch::Adapter)
      ::ActiveContext::Adapter.instance_variable_set(:@current, mock_adapter)

      expect(::ActiveContext::Adapter.instance_variable_get(:@current)).to eq(mock_adapter)

      connection.reload_adapter

      expect(::ActiveContext::Adapter.instance_variable_get(:@current)).to be_nil
    end

    context 'when called as an after_save callback' do
      it 'clears the adapter cache after saving' do
        mock_adapter = instance_double(::ActiveContext::Databases::Elasticsearch::Adapter)
        ::ActiveContext::Adapter.instance_variable_set(:@current, mock_adapter)

        connection.update!(name: 'updated_name')

        expect(::ActiveContext::Adapter.instance_variable_get(:@current)).to be_nil
      end
    end

    context 'when a new connection is activated' do
      let_it_be(:old_connection) { create(:ai_active_context_connection) }
      let_it_be_with_reload(:new_connection) { create(:ai_active_context_connection, :inactive) }
      let(:old_adapter) { instance_double(::ActiveContext::Databases::Elasticsearch::Adapter) }
      let(:new_adapter) { instance_double(::ActiveContext::Databases::Elasticsearch::Adapter) }

      before do
        allow(::ActiveContext::Adapter).to receive(:for_connection).with(old_connection).and_return(old_adapter)
        allow(::ActiveContext::Adapter).to receive(:for_connection).with(new_connection).and_return(new_adapter)
      end

      it 'updates the adapter when the active connection changes' do
        expect(::ActiveContext.adapter).to eq(old_adapter)

        new_connection.activate!

        expect(::ActiveContext.adapter).to eq(new_adapter)
      end
    end
  end
end
