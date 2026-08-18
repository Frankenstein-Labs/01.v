# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_contexts'

RSpec.describe Ai::ActiveContext::Code::Indexer, feature_category: :global_search do
  let_it_be_with_reload(:connection) { create(:ai_active_context_connection) }
  let_it_be(:collection) do
    create(:ai_active_context_collection, connection: connection)
  end

  let_it_be(:project) { create(:project, :small_repo) }
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

  let(:indexer) { described_class.new(repository) }
  let(:block) { proc { |id| processed_ids << id } }
  let(:processed_ids) { [] }

  subject(:run) { indexer.run(&block) }

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
      project_id: repository.project.id,
      from_sha: Gitlab::Git::SHA1_BLANK_SHA,
      to_sha: project.repository.commit.id
    }.merge(extra_params).stringify_keys
  end

  describe '.run!' do
    it 'delegates to the instance method #run' do
      indexer_double = instance_double(described_class, run: nil)
      allow(described_class).to receive(:new).with(repository).and_return(indexer_double)

      expect(indexer_double).to receive(:run).and_yield('test_value')
      described_class.run!(repository, &block)
    end
  end

  describe '#run' do
    context 'when adapter is available' do
      let(:expected_to_commit) { project.repository.commit.id }
      let(:expected_from_sha) { Gitlab::Git::SHA1_BLANK_SHA }
      let(:expected_force_reindex) { false }

      describe 'command execution' do
        let(:env_vars) { { "GITLAB_INDEXER_MODE" => "chunk" } }
        let(:expected_options) do
          {
            project_id: project.id,
            partition_name: collection.name,
            partition_number: collection.partition_for(project.id),
            timeout: described_class::TIMEOUT,
            from_sha: expected_from_sha,
            to_sha: expected_to_commit,
            force_reindex: expected_force_reindex,
            gitaly_config: {
              storage: project.repository_storage,
              relative_path: project.repository.relative_path,
              project_path: project.full_path
            }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage)),
            chunk_strategy: collection.chunk_strategy,
            chunk_size: collection.chunk_strategy_size
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

        it 'calls the indexer with the correct command' do
          expect(Gitlab::Popen).to receive(:popen_with_streaming)
            .with(expected_command, nil, env_vars)
            .and_return(0)

          run
        end

        describe 'gitaly_config' do
          it 'includes address and authentication data from connection_data' do
            expect(Gitlab::GitalyClient).to receive(:connection_data)
              .with(project.repository_storage)
              .and_return(address: 'unix:/tmp/gitaly.socket', token: 'test-token')

            expect(Gitlab::Popen).to receive(:popen_with_streaming) do |command, _dir, _env|
              # Find the -options flag and get the JSON that follows it
              options_index = command.find_index('-options')
              options_json = command[options_index + 1]
              options = Gitlab::Json.parse(options_json)
              gitaly_config = options['gitaly_config']

              expect(gitaly_config).to include('address' => 'unix:/tmp/gitaly.socket')
              expect(gitaly_config).to include('token' => 'test-token')
              expect(gitaly_config).to include('storage' => project.repository_storage)
              expect(gitaly_config).to include('relative_path' => project.repository.relative_path)
              expect(gitaly_config).to include('project_path' => project.full_path)

              0
            end

            run
          end
        end

        describe 'connection option' do
          shared_examples 'passes correct connection options' do
            it 'passes the expected connection options' do
              expect(Gitlab::Popen).to receive(:popen_with_streaming) do |command, dir, env|
                expect(command[2]).to eq(adapter_name)
                expect(command[3]).to eq('-connection')

                connection_hash = ::Gitlab::Json.parse(command[4])
                expect(connection_hash).to eq(expected_connection_hash)

                expect(dir).to be_nil
                expect(env).to eq(env_vars)

                0
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

        describe 'update scenarios' do
          shared_examples 'normal indexing update' do
            let(:expected_from_sha) { repository_last_commit }
            let(:expected_to_sha) { git_repository.commit.id }
            let(:expected_force_reindex) { false }

            it 'calls the indexer with force_reindex=false' do
              expect(Gitlab::Popen).to receive(:popen_with_streaming)
                .with(expected_command, nil, env_vars)
                .and_return(0)

              run
            end
          end

          shared_examples 'forced reindexing' do
            let(:expected_from_sha) { git_repository.empty_tree_id }
            let(:expected_to_sha) { git_repository.commit.id }
            let(:expected_force_reindex) { true }

            it 'calls the indexer with force_reindex=true' do
              expect(Gitlab::Popen).to receive(:popen_with_streaming)
                .with(expected_command, nil, env_vars)
                .and_return(0)

              expect(logger).to receive(:info).with(
                build_log_payload('git_repository_contains_last_indexed_commit?', from_sha: nil, duration_s: anything)
              ).ordered

              if with_last_ancestor_check
                expect(logger).to receive(:info).with(
                  build_log_payload('last_indexed_commit_ancestor_of_to_sha?', from_sha: nil, duration_s: anything)
                ).ordered
              end

              run
            end
          end

          before do
            # `repository` refers to the Ai::ActiveContext::Code::Repository record
            # set the Ai::ActiveContext::Code::Repository#last_commit a commit not in the git repository
            # in this example, we are using a commit from GitLab AIGW
            repository.update!(last_commit: repository_last_commit)
          end

          let(:git_repository) { project.repository }

          context 'when the git repository no longer contains the last indexed commit' do
            let(:repository_last_commit) do
              # set the Ai::ActiveContext::Code::Repository#last_commit a commit not in the git repository
              # in this example, we are using a commit from GitLab AIGW
              "3b13b8d3573f096ade95789818d37c80bdbbcdcf"
            end

            it_behaves_like 'forced reindexing' do
              let(:with_last_ancestor_check) { false }
            end
          end

          context 'when the last indexed commit was the empty tree id' do
            let(:repository_last_commit) { git_repository.empty_tree_id }

            it_behaves_like 'normal indexing update'
          end

          context 'when the git repository still contains the last indexed commit' do
            let(:repository_last_commit) do
              # get the git repository's 10th latest commit
              git_repository.commits('master', limit: 10).last.id
            end

            context 'when the last indexed commit is an ancestor of the latest commit' do
              it_behaves_like 'normal indexing update'
            end

            context 'when last_indexed_commit is not an ancestor of the latest commit' do
              before do
                allow_next_instance_of(Repository) do |git_repo_instance|
                  allow(git_repo_instance).to receive(:ancestor?).with(
                    repository_last_commit, git_repository.commit.id
                  ).and_return(false)
                end
              end

              it_behaves_like 'forced reindexing' do
                let(:with_last_ancestor_check) { true }
              end
            end
          end
        end
      end

      context 'when indexer command succeeds' do
        before do
          allow(Gitlab::Popen).to receive(:popen_with_streaming) do |_cmd, _dir, _env, &stream_block|
            stream_block.call(:stdout, "--section-start--\n")
            stream_block.call(:stdout, "version,build_time\n")
            stream_block.call(:stdout, "v5.6.0-16-gb587744-dev,2025-06-24-0800 UTC\n")
            stream_block.call(:stdout, "--section-start--\n")
            stream_block.call(:stdout, "id\n")
            stream_block.call(:stdout, "1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\n")
            stream_block.call(:stdout, "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890\n")
            0
          end
        end

        it 'processes streamed output and calls block for each hash ID' do
          expect(repository).to receive(:update!).with(last_commit: expected_to_commit)

          expect(logger).to receive(:info).with(build_log_payload('Run indexer', duration_s: anything)).ordered
          expect(logger).to receive(:info).with(build_log_payload('Indexer successful', status: 0)).ordered

          run

          expect(processed_ids).to eq(%w[
            1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
            abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
          ])
        end
      end

      context 'when indexer command fails' do
        before do
          allow(Gitlab::Popen).to receive(:popen_with_streaming) do |_cmd, _dir, _env, &stream_block|
            stream_block.call(:stderr, "Command failed with error\n")
            stream_block.call(:stderr, "Additional error details\n")
            1
          end
        end

        it 'raises an exception with stderr output' do
          stderr_error = "Command failed with error\nAdditional error details\n"

          expect(logger).to receive(:error).with(build_log_payload(
            "Indexer failed",
            status: 1,
            error_details: stderr_error
          ))

          expect { run }.to raise_error(
            described_class::Error,
            "Indexer failed with status: 1 and error: #{stderr_error}"
          )
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
