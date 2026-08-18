# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'blobs', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'blobs', :elastic_delete_by_query, :sidekiq_inline do
    let_it_be(:project_private) { create(:project, :repository, :private) }

    before do
      project.repository.index_commits_and_blobs
      project_private.repository.index_commits_and_blobs

      ensure_elasticsearch_index!
    end

    def search_for(term)
      described_class.new(user, term).objects('blobs').map(&:path)
    end

    shared_examples 'blobs scoped results' do
      it_behaves_like 'a paginated object', 'blobs'

      it 'finds blobs' do
        results = described_class.new(user, 'def')
        blobs = results.objects('blobs')

        expect(blobs.first.data).to include('def')
        result_project_ids = results.objects('blobs').map(&:project_id).uniq
        expect(result_project_ids).to include(project.id)
      end

      it 'finds blobs by prefix search' do
        results = described_class.new(user, 'defau*')
        blobs = results.objects('blobs')

        expect(blobs.first.data).to match(/default/i)
        expect(results.blobs_count).to eq 3
      end

      it 'finds blobs from projects requested if user has access' do
        results = described_class.new(user, 'def')
        result_project_ids = results.objects('blobs').map(&:project_id).uniq

        expect(result_project_ids).to include(project.id)
        expect(result_project_ids).not_to include(project_private.id)

        project_private.add_reporter(user)
        results = described_class.new(user, 'def')
        result_project_ids = results.objects('blobs').map(&:project_id).uniq

        expect(result_project_ids).to include(project.id)
        expect(result_project_ids).to include(project_private.id)
      end

      it 'returns zero when blobs are not found' do
        results = described_class.new(user, 'asdfg')

        expect(results.blobs_count).to eq 0
      end

      describe 'searches CamelCased methods' do
        let_it_be(:file_name) { "#{SecureRandom.uuid}.txt" }

        before_all do
          project.repository.create_file(
            user,
            file_name,
            ' function writeStringToFile(){} ',
            message: 'added test file',
            branch_name: 'master')
        end

        it 'find by first word' do
          expect(search_for('write')).to include(file_name)
        end

        it 'find by first two words' do
          expect(search_for('writeString')).to include(file_name)
        end

        it 'find by last two words' do
          expect(search_for('ToFile')).to include(file_name)
        end

        it 'find by exact match' do
          expect(search_for('writeStringToFile')).to include(file_name)
        end

        it 'find by prefix search' do
          expect(search_for('writeStr*')).to include(file_name)
        end
      end

      describe 'searches with special characters', :aggregate_failures do
        let_it_be(:file_prefix) { SecureRandom.hex(8) }

        before do
          code_examples.values.uniq.each do |file_content|
            file_name = "#{file_prefix}-#{Digest::SHA256.hexdigest(file_content)}"
            project.repository.create_file(user, file_name, file_content, message: 'Some commit message',
              branch_name: 'master')
          end

          project.repository.index_commits_and_blobs
          ensure_elasticsearch_index!
        end

        include_context 'with code examples' do
          it 'finds all examples' do
            code_examples.each do |search_term, file_content|
              file_name = "#{file_prefix}-#{Digest::SHA256.hexdigest(file_content)}"

              expect(search_for(search_term)).to include(file_name), "failed to find #{search_term}"
            end
          end
        end
      end

      describe 'filtering' do
        let(:results) { described_class.new(user, query, filters: filters) }

        it_behaves_like 'search results filtered by language'
      end

      describe 'window size' do
        let(:filters) { {} }
        let_it_be(:file_name) { "#{SecureRandom.uuid}.java" }

        subject(:objects) do
          described_class.new(user, 'const_2', filters: filters).objects('blobs')
        end

        before_all do
          # the file cannot be ruby or it affects language filter specs
          project.repository.create_file(
            user,
            file_name,
            "# a comment

          SOME_CONSTANT = 123

          def const
            SOME_CONSTANT
          end

          def const_2
            SOME_CONSTANT * 2
          end

          def const_3
            SOME_CONSTANT * 3
          end",
            message: 'added test file',
            branch_name: 'master')
        end

        before do
          project.repository.index_commits_and_blobs

          ensure_elasticsearch_index!
        end

        it 'returns the line along with 2 lines before and after' do
          expect(objects.count).to eq(1)

          blob = objects.first

          expect(blob.highlight_line).to eq(9)
          expect(blob.data.lines.count).to eq(5)
          expect(blob.startline).to eq(7)
        end

        context 'if num_context_lines is 5' do
          let(:filters) { { num_context_lines: 5 } }

          it 'returns the line along with 5 lines before and after' do
            expect(objects.count).to eq(1)

            blob = objects.first

            expect(blob.highlight_line).to eq(9)
            expect(blob.data.lines.count).to eq(11)
            expect(blob.startline).to eq(4)
          end
        end

        context 'if num_context_lines is 0' do
          let(:filters) { { num_context_lines: 0 } }

          it 'returns only the matched line with no context lines' do
            expect(objects.count).to eq(1)

            blob = objects.first

            expect(blob.highlight_line).to eq(9)
            expect(blob.data.lines.count).to eq(1)
            expect(blob.startline).to eq(9)
          end
        end

        context 'when the matched line is near the end of the file' do
          let_it_be(:near_end_file_name) { "#{SecureRandom.uuid}.java" }
          let(:filters) { { num_context_lines: 1 } }

          subject(:objects) do
            described_class.new(user, 'target_method', filters: filters).objects('blobs')
          end

          before_all do
            project.repository.create_file(
              user,
              near_end_file_name,
              <<~TEXT.chomp,
                # preamble line
                # second line
                def target_method
                end
              TEXT
              message: 'added near-end test file',
              branch_name: 'master')
          end

          it 'includes the context line after the matched line' do
            expect(objects.count).to eq(1)

            blob = objects.first

            expect(blob.highlight_line).to eq(3)
            expect(blob.data.lines.count).to eq(3)
            expect(blob.startline).to eq(2)
          end
        end
      end
    end

    it_behaves_like 'blobs scoped results'
  end
end
