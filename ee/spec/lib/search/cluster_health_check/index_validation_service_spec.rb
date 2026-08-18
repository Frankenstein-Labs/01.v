# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::ClusterHealthCheck::IndexValidationService, feature_category: :global_search do
  let(:elastic_helper) { ::Search::Elastic::Helper.default }
  let(:client) { instance_double(Gitlab::Search::Client) }
  let(:logger) { instance_double(Gitlab::Elasticsearch::Logger) }
  let(:service) { described_class.new }

  before do
    allow(::Search::Elastic::Helper).to receive(:default).and_return(elastic_helper)
    allow(::Gitlab::Search::Client).to receive(:new).and_return(client)
    allow(::Gitlab::Elasticsearch::Logger).to receive(:build).and_return(logger)
    allow(logger).to receive(:is_a?).with(::Gitlab::JsonLogger).and_return(true)
    allow(logger).to receive(:error)
    allow(logger).to receive(:warn)
  end

  describe '#execute' do
    context 'when elasticsearch indexing is disabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it 'returns false and logs a warning' do
        expect(logger).to receive(:warn)
            .with(hash_including('message' => 'The elasticsearch_indexing setting is disabled'))
        expect(service.execute).to be false
      end

      context 'when using a non-standard logger' do
        it 'does not print JSON formatting' do
          custom_logger = Logger.new($stdout)
          service = described_class.new(logger: custom_logger)

          expect(custom_logger).to receive(:warn).with('The elasticsearch_indexing setting is disabled')

          service.execute
        end
      end
    end

    context 'when elasticsearch indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
      end

      context 'when search cluster is not reachable' do
        before do
          allow(elastic_helper).to receive(:ping?).and_return(false)
        end

        it 'returns false' do
          expect(logger).to receive(:warn).with(hash_including('message' => 'The search cluster is unreachable'))

          expect(service.execute).to be false
        end
      end

      context 'when search cluster is reachable' do
        let(:index_response) { { '_shards' => { 'failed' => 0 } } }
        let(:search_response) { { 'hits' => { 'total' => { 'value' => 1 } } } }

        before do
          allow(elastic_helper).to receive_messages(
            ping?: true,
            alias_exists?: true,
            target_index_name: 'test_index',
            klass_to_alias_name: 'gitlab-test')
          allow(client).to receive_messages(index: index_response, search: search_response)
          allow(::Elastic::DataMigrationService).to receive(:migration_has_finished_uncached?).and_return(true)
        end

        it 'returns true when all operations succeed' do
          expect(service.execute).to be true
        end

        context 'when target_classes are passed' do
          let(:service) { described_class.new(target_classes: [::Project]) }

          it 'only checks the requested classes' do
            expect(service.execute).to be true

            expect(client).to have_received(:index).once
            expect(client).to have_received(:search).once
          end

          it 'ignores classes which are not in the known list of indexed classes' do
            expect(described_class.new(target_classes: [::Project, ::MergeRequestAssignee]).execute).to be true

            expect(client).to have_received(:index).once.with(a_hash_including(index: 'test_index'))
            expect(client).to have_received(:search).once.with(a_hash_including(index: 'test_index'))
          end
        end

        context 'when operations are passed' do
          let(:service) { described_class.new(operations: [:search]) }

          it 'only runs the requested operations' do
            expect(service.execute).to be true

            expect(client).not_to have_received(:index)
            expect(client).to have_received(:search).at_least(:once)
          end

          it 'ignores operations which are not in the known list of indexed classes' do
            expect(described_class.new(operations: [:not_supported, :search]).execute).to be true

            expect(client).to have_received(:search).at_least(:once)
          end
        end

        context 'when indexing fails' do
          let(:index_response) { { '_shards' => { 'failed' => 1 } } }

          it 'returns false and logs an error' do
            expect(logger).to receive(:error).with(hash_including('message' => 'index failed'))
            expect(service.execute).to be false
          end
        end

        context 'when search fails' do
          let(:search_response) { { 'hits' => { 'total' => { 'value' => 0 } } } }

          it 'returns false and logs an error' do
            expect(logger).to receive(:error).with(hash_including('message' => 'search failed'))
            expect(service.execute).to be false
          end
        end

        context 'when elasticsearch raises an error not caught by custom errors' do
          before do
            allow(client).to receive(:index)
                               .and_raise(Elasticsearch::Transport::Transport::Errors::NotFound, 'cluster not found')
          end

          it 'returns false and logs the error' do
            expect(logger).to receive(:error)
                                .with(hash_including('message' => 'An error occurred while validating search cluster'))
            expect(service.execute).to be false
          end

          context 'when using a non-structured logger' do
            it 'does not print JSON formatting' do
              custom_logger = Logger.new($stdout)
              service = described_class.new(logger: custom_logger)

              expect(custom_logger).to receive(:error)
                .with('An error occurred while validating search cluster (error_message: cluster not found, ' \
                  'error_class: Elasticsearch::Transport::Transport::Errors::NotFound)')

              service.execute
            end
          end
        end

        context 'when Gitlab::Search::Client::ConnectionError is raised' do
          before do
            allow(client).to receive(:index)
              .and_raise(Gitlab::Search::Client::ConnectionError.new('Connection refused'))
          end

          it 'returns false and logs the error' do
            expect(logger).to receive(:error)
              .with(hash_including('message' => 'An error occurred while validating search cluster',
                'error_message' => 'Search is currently unavailable. Please try again later.',
                'error_class' => 'Gitlab::Search::Client::ConnectionError'))
            expect(service.execute).to be false
          end
        end

        context 'when Gitlab::Search::Client::AuthorizationError is raised' do
          before do
            allow(client).to receive(:index)
              .and_raise(Gitlab::Search::Client::AuthorizationError.new('Unauthorized'))
          end

          it 'returns false and logs the error' do
            expect(logger).to receive(:error)
              .with(hash_including('message' => 'An error occurred while validating search cluster',
                'error_message' => 'Search authentication failed. Please check your advanced search configuration.',
                'error_class' => 'Gitlab::Search::Client::AuthorizationError'))
            expect(service.execute).to be false
          end
        end

        context 'when an alias does not exist' do
          before do
            allow(elastic_helper).to receive(:alias_exists?).and_return(false)
          end

          it 'returns false and logs an error' do
            aliases.each do |alias_name|
              expect(logger).to receive(:error)
              .with(hash_including('message' => 'The alias does not exist', 'alias_name' => alias_name))
            end

            expect(service.execute).to be false
          end
        end

        context 'when a class has a pending create-index migration' do
          let(:create_index_migration) do
            ::Elastic::DataMigrationService.find_by_name(:create_vulnerability_reads_index)
          end

          before do
            allow(::Elastic::DataMigrationService).to receive(:migration_has_finished_uncached?)
              .with(create_index_migration.name_for_key)
              .and_return(false)
          end

          it 'does not attempt to validate the pending index and returns true for the remaining indices' do
            vulnerability_read_alias = elastic_helper.klass_to_alias_name(klass: ::Vulnerabilities::Read)

            expect(client).not_to receive(:index).with(hash_including(index: vulnerability_read_alias))
            expect(client).not_to receive(:search).with(hash_including(index: vulnerability_read_alias))

            expect(service.execute).to be true
          end
        end
      end
    end
  end

  describe '.execute' do
    it 'creates a new instance and calls execute' do
      service_instance = instance_double(described_class)
      expect(described_class).to receive(:new).and_return(service_instance)
      expect(service_instance).to receive(:execute)

      described_class.execute
    end

    it 'passes logger parameter to the constructor' do
      service_instance = instance_double(described_class)
      custom_logger = instance_double(Gitlab::Elasticsearch::Logger)
      expect(described_class).to receive(:new).with(logger: custom_logger).and_return(service_instance)
      expect(service_instance).to receive(:execute)

      described_class.execute(logger: custom_logger)
    end
  end

  describe '#initialize' do
    let_it_be(:custom_logger) { Logger.new($stdout) }

    context 'when custom logger is provided' do
      it 'uses the provided logger' do
        service = described_class.new(logger: custom_logger)

        expect(service.send(:logger)).to eq(custom_logger)
      end
    end

    it 'defaults to Gitlab::Elasticsearch::Logger.build when no logger provided' do
      expect(described_class.new.send(:logger)).to eq(logger)
    end
  end

  private

  def aliases
    standalone_indices = elastic_helper.standalone_indices_proxies
    standalone_indices.map(&:index_name) + [elastic_helper.target_name]
  end
end
