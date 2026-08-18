# frozen_string_literal: true

require 'fast_spec_helper'

require_relative '../../../../../lib/gitlab/duo/administration/review_instructions_linter'

RSpec.describe Gitlab::Duo::Administration::ReviewInstructionsLinter, feature_category: :duo_code_review do
  let(:path) { '/fake/mr-review-instructions.yaml' }
  let(:content) { '' }
  let(:linter) { described_class.new(path).run }

  before do
    allow(File).to receive(:file?).and_call_original
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:file?).with(path).and_return(true)
    allow(File).to receive(:read).with(path).and_return(content)
  end

  describe '#run' do
    context 'with a valid file' do
      let(:content) do
        <<~YAML
          instructions:
            - name: Ruby
              fileFilters:
                - "**/*.rb"
                - "!spec/**/*.rb"
              instructions: |
                Use snake_case.
        YAML
      end

      it 'reports no issues', :aggregate_failures do
        expect(linter.issues).to be_empty
        expect(linter).to be_valid
      end
    end

    context 'with a missing file' do
      let(:linter) { described_class.new('/nonexistent/file.yaml').run }

      it 'reports E001' do
        expect(linter.errors.map(&:code)).to contain_exactly('E001')
      end
    end

    context 'with an empty file' do
      let(:content) { '' }

      it 'warns with W007 and stays valid', :aggregate_failures do
        expect(linter).to be_valid
        expect(linter.warnings.map(&:code)).to contain_exactly('W007')
      end
    end

    context 'with invalid YAML syntax' do
      let(:content) { "instructions:\n  - name: \"unterminated" }

      it 'reports E003' do
        expect(linter.errors.map(&:code)).to contain_exactly('E003')
      end
    end

    context 'when top-level is not a mapping' do
      let(:content) { "- just\n- a\n- list\n" }

      it 'reports E004' do
        expect(linter.errors.map(&:code)).to contain_exactly('E004')
      end
    end

    context 'when instructions key is missing' do
      let(:content) { "rules:\n  - foo\n" }

      it 'reports E005 and warns about the unknown key', :aggregate_failures do
        expect(linter.errors.map(&:code)).to contain_exactly('E005')
        expect(linter.warnings.map(&:code)).to include('W001')
      end
    end

    context 'when instructions is not a list' do
      let(:content) { "instructions: 'a string'\n" }

      it 'reports E006' do
        expect(linter.errors.map(&:code)).to contain_exactly('E006')
      end
    end

    context 'when instructions list is empty' do
      let(:content) { "instructions: []\n" }

      it 'emits W002', :aggregate_failures do
        expect(linter.errors).to be_empty
        expect(linter.warnings.map(&:code)).to contain_exactly('W002')
      end
    end

    context 'when an entry is not a mapping' do
      let(:content) { "instructions:\n  - just-a-string\n" }

      it 'reports E007' do
        expect(linter.errors.map(&:code)).to include('E007')
      end
    end

    context 'with missing required fields' do
      let(:content) do
        <<~YAML
          instructions:
            - name: ""
              fileFilters: ["*.rb"]
              instructions: ""
        YAML
      end

      it 'reports E008 and E009' do
        codes = linter.errors.map(&:code)
        expect(codes).to include('E008', 'E009')
      end
    end

    context 'with non-string scalar values for name and instructions' do
      let(:content) do
        <<~YAML
          instructions:
            - name: 42
              fileFilters: ["*.rb"]
              instructions: true
        YAML
      end

      it 'reports E008 and E009 because the values are not strings' do
        codes = linter.errors.map(&:code)
        expect(codes).to include('E008', 'E009')
      end
    end

    context 'with the typo from issue 4868 / MR 238983' do
      let(:content) do
        <<~YAML
          instructions:
            - name: "General instructions"
              rules: "Do something"
        YAML
      end

      it 'reports missing instructions, warns about unknown rules, and infos about fileFilters', :aggregate_failures do
        expect(linter.errors.map(&:code)).to include('E009')
        expect(linter.warnings.map(&:code)).to include('W003')
        expect(linter.info.map(&:code)).to include('I001')
      end
    end

    context 'when fileFilters is missing' do
      let(:content) do
        <<~YAML
          instructions:
            - name: A
              instructions: B
        YAML
      end

      it 'emits I001 and stays valid', :aggregate_failures do
        expect(linter).to be_valid
        expect(linter.warnings).to be_empty
        expect(linter.info.map(&:code)).to contain_exactly('I001')
      end
    end

    context 'when fileFilters is not a list' do
      let(:content) do
        <<~YAML
          instructions:
            - name: A
              instructions: B
              fileFilters: "*.rb"
        YAML
      end

      it 'reports E011' do
        expect(linter.errors.map(&:code)).to contain_exactly('E011')
      end
    end

    context 'when fileFilters is empty' do
      let(:content) do
        <<~YAML
          instructions:
            - name: A
              instructions: B
              fileFilters: []
        YAML
      end

      it 'emits I002 and stays valid', :aggregate_failures do
        expect(linter).to be_valid
        expect(linter.warnings).to be_empty
        expect(linter.info.map(&:code)).to contain_exactly('I002')
      end
    end

    context 'when fileFilters entries have wrong types or are blank' do
      let(:content) do
        <<~YAML
          instructions:
            - name: A
              instructions: B
              fileFilters:
                - 42
                - ""
        YAML
      end

      it 'reports E013 and E014' do
        codes = linter.errors.map(&:code)
        expect(codes).to include('E013', 'E014')
      end
    end

    context 'with duplicate names' do
      let(:content) do
        <<~YAML
          instructions:
            - name: Same
              fileFilters: ["*.rb"]
              instructions: One
            - name: Same
              fileFilters: ["*.ts"]
              instructions: Two
        YAML
      end

      it 'warns with W004 and stays valid', :aggregate_failures do
        expect(linter).to be_valid
        expect(linter.warnings.map(&:code)).to contain_exactly('W004')
      end
    end
  end

  describe '#initialize' do
    context 'with no argument' do
      let(:linter) { described_class.new.run }

      it 'defaults to .gitlab/duo/mr-review-instructions.yaml' do
        expect(linter.file_path).to eq('.gitlab/duo/mr-review-instructions.yaml')
      end
    end

    context 'with nil argument' do
      let(:linter) { described_class.new(nil).run }

      it 'defaults to .gitlab/duo/mr-review-instructions.yaml' do
        expect(linter.file_path).to eq('.gitlab/duo/mr-review-instructions.yaml')
      end
    end
  end
end
