# frozen_string_literal: true

module Ai
  module ActiveContext
    module Code
      class Indexer < IndexerBase
        def self.run!(active_context_repository, &block)
          new(active_context_repository).run(&block)
        end

        def run(&block)
          raise Error, 'Adapter not set' unless adapter

          # determine the commit-related values at the beginning of indexing
          # to ensure we are logging the correct values
          determine_shas_and_force_reindex_flag

          response_processor = IndexerResponseModifier.new(&block)
          stderr_output = []

          status = log_duration('Run indexer') do
            Gitlab::Popen.popen_with_streaming(command, nil, environment_variables) do |stream_type, line|
              case stream_type
              when :stdout
                response_processor.process_line(line)
              when :stderr
                stderr_output << line
              end
            end
          end

          unless status == 0
            log_error(
              "Indexer failed",
              status: status,
              error_details: stderr_output.join
            )
            raise Error, "Indexer failed with status: #{status} and error: #{stderr_output.join}"
          end

          log_info('Indexer successful', status: status)

          active_context_repository.update!(last_commit: to_sha)
        end

        private

        attr_reader :from_sha, :to_sha, :force_reindex

        def determine_shas_and_force_reindex_flag
          @to_sha = project_repository.commit&.id
          raise Error, "Project repository commit not found" unless @to_sha

          if force_push?
            @from_sha = project_repository.empty_tree_id
            @force_reindex = true
            return
          end

          @from_sha = last_indexed_commit
          @force_reindex = false
        end

        def force_push?
          if last_indexed_commit.blank? ||
              Gitlab::Git.blank_ref?(last_indexed_commit) ||
              last_indexed_commit == project_repository.empty_tree_id
            return false
          end

          # force-push if the last_indexed_commit is no longer reachable in the repository
          return true unless git_repository_contains_last_indexed_commit?

          # force-push if the last_indexed_commit is NOT an ancestor of the to_sha (latest commit)
          !last_indexed_commit_ancestor_of_to_sha?
        end

        def last_indexed_commit
          @last_indexed_commit ||= active_context_repository.last_commit
        end

        def git_repository_contains_last_indexed_commit?
          log_duration('git_repository_contains_last_indexed_commit?') do
            last_indexed_commit.present? && project_repository.commit(last_indexed_commit).present?
          end
        end

        def last_indexed_commit_ancestor_of_to_sha?
          log_duration('last_indexed_commit_ancestor_of_to_sha?') do
            project_repository.ancestor?(last_indexed_commit, to_sha)
          end
        end

        def options
          base_options.merge(
            {
              from_sha: from_sha,
              to_sha: to_sha,
              force_reindex: force_reindex,
              gitaly_config: gitaly_config,
              chunk_strategy: collection_class.collection_record.chunk_strategy,
              chunk_size: collection_class.collection_record.chunk_strategy_size
            }
          )
        end

        def gitaly_config
          {
            storage: project.repository_storage,
            relative_path: project_repository.relative_path,
            project_path: project.full_path
          }.merge(Gitlab::GitalyClient.connection_data(project.repository_storage))
        end

        def build_log_payload(message, extra_params = {})
          super(message, extra_params.merge(from_sha: from_sha, to_sha: to_sha))
        end
      end
    end
  end
end
