# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::PatternIndex, feature_category: :source_code_management do
  include FakeBlobHelpers

  let_it_be(:project) { create(:project) }

  subject(:pattern_index) { described_class.new(parsed_data) }

  def build_parsed_data(content)
    blob = fake_blob(path: 'CODEOWNERS', data: content)
    Gitlab::CodeOwners::File.new(blob).parsed_data
  end

  describe '#entries_for_path' do
    context 'for indexing-specific edge cases' do
      context 'with empty parsed_data' do
        let(:parsed_data) { build_parsed_data('') }

        it 'returns an empty array' do
          expect(pattern_index.entries_for_path('anything.rb')).to be_empty
        end
      end

      context 'with no matches' do
        let(:parsed_data) { build_parsed_data('/specific/file.txt @owner') }

        it 'returns an empty array' do
          expect(pattern_index.entries_for_path('other/path.rb')).to be_empty
        end
      end

      context 'with mixed trie and fallback patterns' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            *.rb @ruby-team
            /app/models/ @models-team
          CODEOWNERS
        end

        it 'prefers trie matches while keeping fallback candidates available', :aggregate_failures do
          models_entry = pattern_index.entries_for_path('app/models/user.rb').first
          other_entry = pattern_index.entries_for_path('lib/helper.rb').first

          expect(models_entry.owner_line).to eq('@models-team')
          expect(other_entry.owner_line).to eq('@ruby-team')
        end
      end

      context 'with deep nesting' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            /a/b/c/d/e/ @deep-team
          CODEOWNERS
        end

        it 'matches deeply nested paths and rejects shorter prefixes', :aggregate_failures do
          entry = pattern_index.entries_for_path('a/b/c/d/e/file.txt').first

          expect(entry.owner_line).to eq('@deep-team')
          expect(pattern_index.entries_for_path('a/b/c/file.txt')).to be_empty
        end
      end

      context 'when exact file and same-named directory patterns coexist' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            /app/file @file-owner
            /app/file/ @dir-owner
          CODEOWNERS
        end

        it 'keeps exact file and directory candidates distinct', :aggregate_failures do
          file_entry = pattern_index.entries_for_path('app/file').first
          nested_entry = pattern_index.entries_for_path('app/file/nested.txt').first

          expect(file_entry.owner_line).to eq('@file-owner')
          expect(nested_entry.owner_line).to eq('@dir-owner')
        end
      end

      context 'with exclusions across indexed and fallback candidates' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            * @default-team
            !*.rb
            !/app/temp/

            [Ruby]
            *.rb @ruby-team
          CODEOWNERS
        end

        it 'applies exclusions per section for both candidate sources', :aggregate_failures do
          expect(pattern_index.entries_for_path('test.rb').map(&:section)).to contain_exactly('Ruby')
          expect(pattern_index.entries_for_path('app/temp/file.rb').map(&:section)).to contain_exactly('Ruby')
          expect(pattern_index.entries_for_path('docs/file.txt').first.owner_line).to eq('@default-team')
        end
      end

      context 'when duplicate patterns are redefined' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            /src/ @team-a
            /src/components/ @frontend
            /src/ @team-b
          CODEOWNERS
        end

        it 'keeps the last matching entry for duplicate patterns' do
          entry = pattern_index.entries_for_path('src/components/Button.vue').first

          expect(entry.owner_line).to eq('@team-b')
        end
      end

      context 'with escaped static prefixes' do
        let(:parsed_data) do
          build_parsed_data(<<~'CODEOWNERS')
            /dir\!name/file.rb @owner
          CODEOWNERS
        end

        it 'matches through fallback parity with fnmatch escapes' do
          entry = pattern_index.entries_for_path('dir!name/file.rb').first

          expect(entry.owner_line).to eq('@owner')
        end
      end

      context 'when an exclusion matches before later positives' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            /app/ @app-team
            /app/**/*.txt @special-team
            !**/special.txt
          CODEOWNERS
        end

        it 'suppresses the section' do
          expect(pattern_index.entries_for_path('app/special.txt')).to be_empty
        end
      end

      context 'with paths that have leading slash' do
        let(:parsed_data) do
          build_parsed_data(<<~CODEOWNERS)
            /app/ @app-team
          CODEOWNERS
        end

        it 'normalizes paths at the pattern index boundary' do
          entry = pattern_index.entries_for_path('/app/file.rb').first

          expect(entry.owner_line).to eq('@app-team')
        end
      end
    end
  end
end
