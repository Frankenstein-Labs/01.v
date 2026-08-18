# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::ReviewMergeRequest, feature_category: :duo_code_review do
  let(:diffs_and_paths) do
    {
      'UPDATED.md' => <<~RAWDIFF
      @@ -1,4 +1,4 @@
       # UPDATED

      -Welcome
      -This is an updated file
      +Welcome!
      +This is an updated file.
      @@ -10,3 +10,3 @@
       # ANOTHER HUNK

      -This is an old line
      +This is a new line
      RAWDIFF
    }
  end

  let(:new_path) { 'UPDATED.md' }
  let(:user) { build(:user) }
  let(:mr_title) { 'Fix typos in welcome message' }
  let(:mr_description) { 'Improving readability by fixing typos and adding proper punctuation.' }
  let(:files_content) do
    {
      'UPDATED.md' =>
        "@@ -1,4 +1,4 @@\n # UPDATED\n-Welcome\n-This is an updated file\n+Welcome!\n+This is an updated file."
    }
  end

  describe '#to_prompt_inputs' do
    let(:expected_diff_lines) do
      <<~DIFF.chomp
        <file_diff filename="UPDATED.md">
        <line type="context" old_line="1" new_line="1"># UPDATED</line>
        <line type="context" old_line="2" new_line="2"></line>
        <line type="deleted" old_line="3" new_line="">Welcome</line>
        <line type="deleted" old_line="4" new_line="">This is an updated file</line>
        <line type="added" old_line="" new_line="3">Welcome!</line>
        <line type="added" old_line="" new_line="4">This is an updated file.</line>
        <chunk_header>@@ -10,3 +10,3 @@</chunk_header>
        <line type="context" old_line="10" new_line="10"># ANOTHER HUNK</line>
        <line type="context" old_line="11" new_line="11"></line>
        <line type="deleted" old_line="12" new_line="">This is an old line</line>
        <line type="added" old_line="" new_line="12">This is a new line</line>
        </file_diff>
      DIFF
    end

    let(:expected_full_file_intro) do
      " You will also be provided with the original content of modified files (before changes) " \
        "to help you better understand the context and scope of changes. " \
        "Newly added files are not included as their full content is already in the diffs."
    end

    let(:expected_full_content_section) do
      <<~CONTENT.chomp
        <original_files>
        Use this context to better understand the changes and identify genuine issues in the code.

        Original file content (before changes):

        <full_file filename="UPDATED.md">
        @@ -1,4 +1,4 @@
         # UPDATED
        -Welcome
        -This is an updated file
        +Welcome!
        +This is an updated file.
        </full_file>
        </original_files>
      CONTENT
    end

    subject(:prompt_inputs) do
      described_class.new(
        mr_title: mr_title,
        mr_description: mr_description,
        diffs_and_paths: diffs_and_paths,
        files_content: files_content,
        user: user
      ).to_prompt_inputs
    end

    shared_examples 'builds prompt inputs' do
      it 'returns prompt inputs' do
        expect(prompt_inputs).to eq({
          mr_title: mr_title,
          mr_description: mr_description,
          diff_lines: expected_diff_lines,
          full_file_intro: expected_full_file_intro,
          full_content_section: expected_full_content_section,
          custom_instructions_section: ""
        })
      end
    end

    it_behaves_like 'builds prompt inputs'

    context 'when files_content is empty' do
      let(:files_content) { {} }
      let(:expected_full_file_intro) { '' }
      let(:expected_full_content_section) { '' }

      it_behaves_like 'builds prompt inputs'
    end

    context 'with multiple files' do
      let(:diffs_and_paths) do
        {
          'UPDATED.md' =>
          "@@ -1,4 +1,4 @@\n # UPDATED\n-Welcome\n-This is an updated file\n+Welcome!\n+This is an updated file.",
          'OTHER.md' => "@@ -5,3 +5,3 @@\n # CONTENT\n-This is old content\n+This is updated content"
        }
      end

      let(:files_content) do
        {
          'UPDATED.md' => "# UPDATED\nWelcome!\nThis is an updated file.\n\n...",
          'OTHER.md' => "Some header\n\n...\n\n# CONTENT\n\nThis is updated content"
        }
      end

      let(:expected_diff_lines) do
        <<~DIFF.chomp
          <file_diff filename="UPDATED.md">
          <line type="context" old_line="1" new_line="1"># UPDATED</line>
          <line type="deleted" old_line="2" new_line="">Welcome</line>
          <line type="deleted" old_line="3" new_line="">This is an updated file</line>
          <line type="added" old_line="" new_line="2">Welcome!</line>
          <line type="added" old_line="" new_line="3">This is an updated file.</line>
          </file_diff>

          <file_diff filename="OTHER.md">
          <chunk_header>@@ -5,3 +5,3 @@</chunk_header>
          <line type="context" old_line="5" new_line="5"># CONTENT</line>
          <line type="deleted" old_line="6" new_line="">This is old content</line>
          <line type="added" old_line="" new_line="6">This is updated content</line>
          </file_diff>
        DIFF
      end

      let(:expected_full_content_section) do
        <<~CONTENT.chomp
          <original_files>
          Use this context to better understand the changes and identify genuine issues in the code.

          Original file content (before changes):

          <full_file filename="UPDATED.md">
          # UPDATED
          Welcome!
          This is an updated file.

          ...
          </full_file>

          <full_file filename="OTHER.md">
          Some header

          ...

          # CONTENT

          This is updated content
          </full_file>
          </original_files>
        CONTENT
      end

      it_behaves_like 'builds prompt inputs'
    end

    context 'with custom instructions' do
      subject(:prompt_inputs) do
        described_class.new(
          mr_title: mr_title,
          mr_description: mr_description,
          diffs_and_paths: diffs_and_paths,
          files_content: files_content,
          user: user,
          custom_instructions: custom_instructions
        ).to_prompt_inputs
      end

      context 'with include patterns only' do
        let(:custom_instructions) do
          [
            {
              name: 'Ruby Style Guide',
              instructions: 'Follow Ruby style conventions and best practices',
              include_patterns: ['*.rb'],
              exclude_patterns: []
            },
            {
              name: 'Markdown Standards',
              instructions: 'Check for proper markdown formatting and structure',
              include_patterns: ['*.md'],
              exclude_patterns: []
            }
          ]
        end

        it 'formats custom instructions section correctly' do
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'For files matching "*.rb" (excluding: none) - Ruby Style Guide:'
          )
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'For files matching "*.md" (excluding: none) - Markdown Standards:'
          )
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'Follow Ruby style conventions and best practices'
          )
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'Check for proper markdown formatting and structure'
          )
        end
      end

      context 'with include and exclude patterns' do
        let(:custom_instructions) do
          [
            {
              name: 'TypeScript Files',
              instructions: 'Review TypeScript code for type safety',
              include_patterns: ['**/*.ts'],
              exclude_patterns: ['**/*.test.ts', '**/*.spec.ts']
            }
          ]
        end

        it 'shows both include and exclude patterns' do
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'For files matching "**/*.ts" (excluding: **/*.test.ts, **/*.spec.ts) - TypeScript Files:'
          )
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'Review TypeScript code for type safety'
          )
        end
      end

      context 'with empty include patterns (matches all files)' do
        let(:custom_instructions) do
          [
            {
              name: 'All Files Review',
              instructions: 'Apply to all files except tests',
              include_patterns: [],
              exclude_patterns: ['**/*.test.*', '**/*.spec.*']
            }
          ]
        end

        it 'shows "all files" for include and specific excludes' do
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'For files matching "all files" (excluding: **/*.test.*, **/*.spec.*) - All Files Review:'
          )
        end
      end

      context 'with empty exclude patterns' do
        let(:custom_instructions) do
          [
            {
              name: 'Security Review',
              instructions: 'Focus on security vulnerabilities',
              include_patterns: ['*.rb'],
              exclude_patterns: []
            }
          ]
        end

        it 'shows specific includes and "none" for excludes' do
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'For files matching "*.rb" (excluding: none) - Security Review:'
          )
        end
      end

      context 'with multiple instructions' do
        let(:custom_instructions) do
          [
            {
              name: 'Ruby Files',
              instructions: 'Ruby style conventions',
              include_patterns: ['*.rb', 'lib/**/*.rb'],
              exclude_patterns: ['spec/**/*.rb']
            },
            {
              name: 'Configuration Files',
              instructions: 'Configuration best practices',
              include_patterns: ['*.yml', '*.yaml'],
              exclude_patterns: []
            }
          ]
        end

        it 'formats all instructions with proper separators' do
          section = prompt_inputs[:custom_instructions_section]
          expect(section).to include('For files matching "*.rb, lib/**/*.rb" (excluding: spec/**/*.rb) - Ruby Files:')
          expect(section).to include('For files matching "*.yml, *.yaml" (excluding: none) - Configuration Files:')
          expect(section).to include('Ruby style conventions')
          expect(section).to include('Configuration best practices')
        end
      end

      context 'when custom instructions is empty' do
        let(:custom_instructions) { [] }

        it 'returns empty string for custom instructions section' do
          expect(prompt_inputs[:custom_instructions_section]).to eq("")
        end
      end

      context 'when include the full custom instructions template' do
        let(:custom_instructions) do
          [
            {
              name: 'Test',
              instructions: 'Test instructions',
              include_patterns: ['*.rb'],
              exclude_patterns: []
            }
          ]
        end

        it 'includes all required template sections' do
          expect(prompt_inputs[:custom_instructions_section]).to include(
            'IMPORTANT: Only apply each custom instruction to files that match its specified pattern.'
          )
          expect(prompt_inputs[:custom_instructions_section]).to include(
            "According to custom instructions in '[instruction_name]': [your comment here]"
          )
          expect(prompt_inputs[:custom_instructions_section]).to include('<custom_instructions>')
          expect(prompt_inputs[:custom_instructions_section]).to include('</custom_instructions>')
        end
      end
    end
  end
end
