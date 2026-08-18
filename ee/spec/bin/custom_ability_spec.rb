# frozen_string_literal: true

require 'fast_spec_helper'
require 'rspec-parameterized'

load File.expand_path('../../bin/custom-ability', __dir__)

RSpec.describe 'bin/custom-ability', feature_category: :permissions do
  using RSpec::Parameterized::TableSyntax

  describe CustomAbilityCreator do
    let(:argv) do
      %w[test_custom_ability
        -t test
        -d test
        -c vulnerability_management
        -r other_ability
        -g
        -p
        -i https://url
        -m http://url]
    end

    let(:options) { CustomAbilityOptionParser.parse(argv) }
    let(:creator) { described_class.new(options) }
    let(:existing_abilities) do
      { 'existing_ability_name' => File.join('', 'config', 'custom_abilities', 'types',
        'existing_ability_name.yml') }
    end

    before do
      allow(creator).to receive(:all_custom_abilities) { existing_abilities }
      allow(creator).to receive(:branch_name).and_return('feature-branch')
      allow(creator).to receive(:editor).and_return(nil)

      # ignore writes
      allow(File).to receive(:write).and_return(true)

      # ignore stdin
      allow(Readline).to receive(:readline).and_raise('EOF')
    end

    subject(:create_custom_ability) { creator.execute }

    it 'properly creates a custom ability' do
      expect(File).to receive(:write).with(
        File.join('ee', 'config', 'custom_abilities', 'test_custom_ability.yml'),
        anything)

      expect do
        create_custom_ability
      end.to output(/name: test_custom_ability/).to_stdout
    end

    context 'when running on master' do
      it 'requires feature branch' do
        expect(creator).to receive(:branch_name).and_return('master')

        expect { create_custom_ability }.to raise_error(CustomAbilityHelpers::Abort, /Create a branch first/)
      end
    end

    context 'with invalid ability names' do
      where(:argv, :ex) do
        %w[.invalid.ability.name] | /Provide a name for the custom ability that is/
        %w[existing_ability_name] | /already exists!/
      end

      with_them do
        it 'raises an error' do
          expect { create_custom_ability }.to raise_error(ex)
        end
      end
    end
  end

  describe CustomAbilityOptionParser do
    describe '.parse' do
      where(:param, :argv, :result) do
        :name                        | %w[foo]                                   | 'foo'
        :amend                       | %w[foo --amend]                           | true
        :force                       | %w[foo -f]                                | true
        :force                       | %w[foo --force]                           | true
        :title                       | %w[foo -t title]                          | 'title'
        :title                       | %w[foo --title title]                     | 'title'
        :description                 | %w[foo -d desc]                           | 'desc'
        :description                 | %w[foo --description desc]                | 'desc'
        :feature_category            | %w[foo -c abilities]                      | 'abilities'
        :feature_category            | %w[foo --feature-category abilities]      | 'abilities'
        :requirements                | %w[foo -r other,abilities]                | %w[other abilities]
        :requirements                | %w[foo --requirements other,abilities]    | %w[other abilities]
        :milestone                   | %w[foo -M 15.6]                           | '15.6'
        :milestone                   | %w[foo --milestone 15.6]                  | '15.6'
        :group_ability               | %w[foo -g]                                | true
        :group_ability               | %w[foo --group_ability]                   | true
        :group_ability               | %w[foo --no-group_ability]                | false
        :project_ability             | %w[foo -p]                                | true
        :project_ability             | %w[foo --project_ability]                 | true
        :project_ability             | %w[foo --no-project_ability]              | false
        :dry_run                     | %w[foo -n]                                | true
        :dry_run                     | %w[foo --dry-run]                         | true
        :introduced_by_mr            | %w[foo -m https://url]                    | 'https://url'
        :introduced_by_mr            | %w[foo --introduced-by-mr https://url]    | 'https://url'
        :introduced_by_issue         | %w[foo -i https://url]                    | 'https://url'
        :introduced_by_issue         | %w[foo --introduced-by-issue https://url] | 'https://url'
      end

      with_them do
        it 'parses option correctly' do
          options = described_class.parse(Array(argv))

          expect(options.public_send(param)).to eq(result)
        end
      end

      it 'raises an error when name of the custom ability is missing' do
        expect do
          expect do
            described_class.parse(%w[--amend])
          end.to output(/Name for the custom ability is required/).to_stdout
        end.to raise_error(CustomAbilityHelpers::Abort)
      end

      it 'parses -h' do
        expect do
          expect { described_class.parse(%w[foo -h]) }.to output(%r{Usage: bin/custom-ability}).to_stdout
        end.to raise_error(CustomAbilityHelpers::Done)
      end
    end

    describe '.read_title' do
      let(:title) { 'Test title' }

      it 'reads title from stdin' do
        expect(Readline).to receive(:readline).and_return(title)
        expect do
          expect(described_class.read_title).to eq('Test title')
        end.to output(/Specify a human-readable title of the ability./).to_stdout
      end

      context 'when title is empty' do
        let(:title) { '' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(title)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_title }.to raise_error(/EOF/)
          end.to output(/Specify a human-readable title of the ability:/)
                   .to_stdout.and output(/title is a required field/).to_stderr
        end
      end
    end

    describe '.read_description' do
      let(:description) { 'This is a test description for a custom ability.' }

      it 'reads description from stdin' do
        expect(Readline).to receive(:readline).and_return(description)
        expect do
          expect(described_class.read_description).to eq('This is a test description for a custom ability.')
        end.to output(/Specify a human-readable description of the ability./).to_stdout
      end

      context 'when description is empty' do
        let(:description) { '' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(description)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_description }.to raise_error(/EOF/)
          end.to output(/Specify a human-readable description of the ability:/)
                   .to_stdout.and output(/description is a required field/).to_stderr
        end
      end
    end

    describe '.read_feature_category' do
      let(:feature_category) { 'abilities' }

      it 'reads feature_category from stdin' do
        expect(Readline).to receive(:readline).and_return(feature_category)
        expect do
          expect(described_class.read_feature_category).to eq('abilities')
        end.to output(/Specify the feature category of this ability like `vulnerability_management`:/).to_stdout
      end

      context 'when feature category is empty' do
        let(:feature_category) { '' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(feature_category)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_feature_category }.to raise_error(/EOF/)
          end.to output(/Specify/)
                   .to_stdout.and output(/feature_category is a required field/).to_stderr
        end
      end
    end

    describe '.read_group_ability' do
      let(:group_ability) { 'true' }

      it 'reads read_group_ability from stdin' do
        expect(Readline).to receive(:readline).and_return(group_ability)
        expect do
          expect(described_class.read_group_ability).to be(true)
        end.to output(/Specify whether this ability is checked on group level/).to_stdout
      end

      context 'when read_group_ability is invalid' do
        let(:group_ability) { 'non boolean value' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(group_ability)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_group_ability }.to raise_error(/EOF/)
          end.to output(/Specify whether this ability is checked on group level/)
                   .to_stdout.and output(/group_ability is a required boolean field/).to_stderr
        end
      end
    end

    describe '.read_project_ability' do
      let(:project_ability) { 'true' }

      it 'reads read_group_ability from stdin' do
        expect(Readline).to receive(:readline).and_return(project_ability)
        expect do
          expect(described_class.read_project_ability).to be(true)
        end.to output(/Specify whether this ability is checked on project level/).to_stdout
      end

      context 'when read_group_ability is invalid' do
        let(:project_ability) { 'non boolean value' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(project_ability)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_project_ability }.to raise_error(/EOF/)
          end.to output(/Specify whether this ability is checked on project level/)
                   .to_stdout.and output(/project_ability is a required boolean field/).to_stderr
        end
      end
    end

    describe '.read_introduced_by_mr' do
      let(:url) { 'https://merge-request' }

      it 'reads introduced_by_mr from stdin' do
        expect(Readline).to receive(:readline).and_return(url)
        expect do
          expect(described_class.read_introduced_by_mr).to eq('https://merge-request')
        end.to output(/URL to GitLab merge request that added this custom ability/).to_stdout
      end

      context 'when URL is empty' do
        let(:url) { '' }

        it 'does not raise an error' do
          expect(Readline).to receive(:readline).and_return(url)

          expect do
            expect(described_class.read_introduced_by_mr).to be_nil
          end.to output(/URL to GitLab merge request that added this custom ability - enter to skip:/).to_stdout
        end
      end

      context 'when URL is invalid' do
        let(:url) { 'invalid' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(url)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_introduced_by_mr }.to raise_error(/EOF/)
          end.to output(/URL to GitLab merge request that added this custom ability - enter to skip:/)
                   .to_stdout.and output(/URL needs to start with https/).to_stderr
        end
      end
    end

    describe '.read_introduced_by_issue' do
      let(:url) { 'https://issue' }

      it 'reads type from stdin' do
        expect(Readline).to receive(:readline).and_return(url)
        expect do
          expect(described_class.read_introduced_by_issue).to eq('https://issue')
        end.to output(/URL to GitLab issue that added this custom ability:/).to_stdout
      end

      context 'when URL is invalid' do
        let(:type) { 'invalid' }

        it 'shows error message and retries' do
          expect(Readline).to receive(:readline).and_return(type)
          expect(Readline).to receive(:readline).and_raise('EOF')

          expect do
            expect { described_class.read_introduced_by_issue }.to raise_error(/EOF/)
          end.to output(/URL to GitLab issue that added this custom ability:/)
                   .to_stdout.and output(/URL needs to start with https/).to_stderr
        end
      end
    end

    describe '.read_milestone' do
      before do
        allow(File).to receive(:read).and_call_original
      end

      it 'returns the correct milestone from the VERSION file' do
        expect(File).to receive(:read).with('VERSION').and_return('15.6.0-pre')
        expect(described_class.read_milestone).to eq('15.6')
      end
    end

    describe '.read_requirements' do
      let(:requirements) { ' ability_a , ability_b ' }

      it 'reads requirements from stdin' do
        expect(Readline).to receive(:readline).and_return(requirements)
        expect do
          expect(described_class.read_requirements).to match_array(%w[ability_a ability_b])
        end.to output(/Specify requirements for enabling this ability/).to_stdout
      end
    end
  end
end
