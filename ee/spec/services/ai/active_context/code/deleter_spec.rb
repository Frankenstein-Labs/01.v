# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_contexts'

RSpec.describe Ai::ActiveContext::Code::Deleter, feature_category: :global_search do
  let_it_be_with_reload(:connection) { create(:ai_active_context_connection) }
  let_it_be(:collection) do
    create(:ai_active_context_collection, connection: connection)
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.first_owner }

  let_it_be_with_reload(:repository) do
    create(:ai_active_context_code_repository, active_context_connection: connection, project: project)
  end

  let(:adapter_name) { 'elasticsearch' }
  let(:adapter) do
    instance_double(
      ::ActiveContext::Databases::Elasticsearch::Adapter,
      name: adapter_name,
      full_collection_name: ActiveContextHelpers.code_collection_name,
      indexer_connection_options: double
    )
  end

  let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil, error: nil) }

  let(:deleter) { described_class.new(repository) }

  subject(:run) { deleter.run }

  before do
    allow(::ActiveContext).to receive(:adapter).and_return(adapter)
    allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
    allow(::ActiveContext).to receive_message_chain(:adapter, :full_collection_name)
      .and_return(ActiveContextHelpers.code_collection_name)
  end

  def build_log_payload(message, extra_params = {})
    {
      class_name: described_class.to_s,
      message: message,
      ai_active_context_code_repository_id: repository.id,
      project_id: repository.project.id
    }.merge(extra_params).stringify_keys
  end

  describe '.run!' do
    it 'delegates to the instance method #run' do
      deleter_double = instance_double(described_class, run: nil)
      allow(described_class).to receive(:new).with(repository).and_return(deleter_double)

      expect(deleter_double).to receive(:run)
      described_class.run!(repository)
    end
  end

  describe '#run' do
    context 'when adapter is available' do
      let(:env_vars) { { "GITLAB_INDEXER_MODE" => "chunk" } }
      let(:expected_options) do
        {
          project_id: project.id,
          partition_name: collection.name,
          partition_number: collection.partition_for(project.id),
          timeout: described_class::TIMEOUT,
          operation: 'delete'
        }
      end

      let(:expected_command) do
        [
          Gitlab.config.elasticsearch.indexer_path,
          '-adapter', adapter_name,
          '-connection', ::Gitlab::Json.generate(adapter.indexer_connection_options),
          '-options', ::Gitlab::Json.generate(expected_options)
        ]
      end

      describe 'command execution' do
        it 'calls the indexer with the correct command' do
          expect(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])

          run
        end

        describe 'connection option' do
          shared_examples 'passes correct connection options' do
            it 'passes the expected connection options' do
              expect(Gitlab::Popen).to receive(:popen) do |command, dir, env|
                expect(command[1..2]).to eq(['-adapter', adapter_name])
                expect(command[3]).to eq('-connection')

                connection_hash = ::Gitlab::Json.parse(command[4])
                expect(connection_hash).to eq(expected_connection_hash)

                expect(dir).to be_nil
                expect(env).to eq(env_vars)

                ["Delete successful\n", 0]
              end

              run
            end
          end

          context 'when elasticsearch adapter' do
            include_context 'with elasticsearch connection options'

            let(:expected_connection_hash) { { 'url' => expected_elasticsearch_urls } }

            it_behaves_like 'passes correct connection options'
          end

          context 'when opensearch adapter' do
            include_context 'with opensearch connection options'

            let(:expected_connection_hash) { expected_opensearch_connection }

            it_behaves_like 'passes correct connection options'
          end
        end
      end

      context 'when delete command succeeds' do
        before do
          allow(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])
        end

        it 'logs success message' do
          expect(logger).to receive(:info).with(
            build_log_payload('Delete successful', status: 0)
          )

          run
        end

        it 'does not raise an error' do
          expect { run }.not_to raise_error
        end

        it 'does not update the repository last_commit' do
          expect(repository).not_to receive(:update!)

          run
        end
      end

      context 'when delete command fails' do
        let(:error_output) { "Failed to delete project embeddings\nConnection timeout" }

        before do
          allow(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return([error_output, 1])
        end

        it 'logs error message with details' do
          expect(logger).to receive(:error).with(
            build_log_payload(
              'Delete failed',
              status: 1,
              error_details: error_output
            )
          )

          expect { run }.to raise_error(described_class::Error)
        end

        it 'raises an exception with error details' do
          expect { run }.to raise_error(
            described_class::Error,
            "Delete failed with status: 1 and error: #{error_output}"
          )
        end
      end

      context 'when the project is deleted' do
        before do
          project.destroy!
        end

        it 'formats connection options correctly for elasticsearch' do
          expect(repository.project).to be_nil

          expect(Gitlab::Popen).to receive(:popen)
            .with(expected_command, nil, env_vars)
            .and_return(["Delete successful\n", 0])

          run
        end
      end
    end

    context 'when adapter is not available' do
      before do
        allow(::ActiveContext).to receive(:adapter).and_return(nil)
      end

      it 'raises an error' do
        expect { run }.to raise_error(described_class::Error, 'Adapter not set')
      end
    end
  end
end
