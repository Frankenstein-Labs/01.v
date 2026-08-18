# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::File, feature_category: :source_code_management do
  include FakeBlobHelpers

  # 'project' is required for the #fake_blob helper
  #
  let_it_be_with_reload(:project) { create(:project, :in_group) }
  let(:blob) { fake_blob(path: 'CODEOWNERS', data: file_content) }

  let(:file_content) do
    File.read(Rails.root.join('ee', 'spec', 'fixtures', 'codeowners_example'))
  end

  subject(:file) { described_class.new(blob) }

  describe '#errors' do
    subject(:errors) { file.errors }

    it { is_expected.to be_instance_of(Gitlab::CodeOwners::Errors) }
  end

  describe '#parsed_data' do
    def owner_line(pattern)
      file.parsed_data["codeowners"][pattern].owner_line
    end

    context 'when handling exclusion patterns' do
      let(:file_content) do
        <<~CONTENT
          * @group-x
          !*.rb

          [Ruby]
          *.rb @ruby-devs
          /config/example.yml @config-yml
          !/config/**/*.rb
        CONTENT
      end

      it 'excludes patterns correctly per section' do
        parsed = file.parsed_data

        expect(parsed['codeowners'].keys).to contain_exactly('/**/*', '/**/*.rb')
        expect(parsed['codeowners']['/**/*'].owner_line).to eq('@group-x')
        expect(parsed['codeowners']['/**/*.rb'].exclusion).to be(true)

        expect(parsed['Ruby'].keys).to contain_exactly('/**/*.rb', '/config/example.yml', '/config/**/*.rb')
        expect(parsed['Ruby']['/**/*.rb'].owner_line).to eq('@ruby-devs')
        expect(parsed['Ruby']['/config/example.yml'].owner_line).to eq('@config-yml')
        expect(parsed['Ruby']['/config/**/*.rb'].exclusion).to be(true)
      end
    end

    context "when CODEOWNERS file contains no sections" do
      it 'parses all the required lines' do
        expected_patterns = [
          '/**/*', '/**/#file_with_pound.rb', '/**/*.rb', '/**/CODEOWNERS', '/**/LICENSE', '/docs/**/*',
          '/docs/*', '/config/**/*', '/**/lib/**/*', '/**/path with spaces/**/*'
        ]

        expect(file.parsed_data["codeowners"].keys)
          .to contain_exactly(*expected_patterns)
      end

      it 'allows usernames and emails' do
        expect(owner_line('/**/LICENSE')).to include('legal', 'janedoe@gitlab.com')
      end
    end

    context "when handling a sectional codeowners file" do
      using RSpec::Parameterized::TableSyntax

      shared_examples_for "creates expected parsed sectional results" do
        it "is a hash sorted by sections without duplicates" do
          data = file.parsed_data

          expect(data.keys.length).to eq(7)
          expect(data.keys).to contain_exactly(
            "codeowners",
            "Documentation",
            "Database",
            "Two Words",
            "Double::Colon",
            "DefaultOwners",
            "OverriddenOwners"
          )
        end

        codeowners_section_paths = [
          "/**/#file_with_pound.rb", "/**/*", "/**/*.rb", "/**/CODEOWNERS",
          "/**/LICENSE", "/**/lib/**/*", "/**/path with spaces/**/*",
          "/config/**/*", "/docs/*", "/docs/**/*"
        ]

        codeowners_section_owners = [
          "@all-docs", "@config-owner", "@default-codeowner",
          "@legal this does not match janedoe@gitlab.com", "@lib-owner",
          "@multiple @owners\t@tab-separated", "@owner-file-with-pound",
          "@root-docs", "@ruby-owner", "@space-owner"
        ]

        where(:section, :patterns, :owners) do
          "codeowners"       | codeowners_section_paths | codeowners_section_owners
          "Documentation"    | ["/**/README.md", "/**/ee/docs", "/**/docs"] | ["@gl-docs"]
          "Database"         | ["/**/README.md", "/**/model/db"] | ["@gl-database"]
          "Two Words"        | ["/**/README.md", "/**/model/db"] | ["@gl-database"]
          "Double::Colon"    | ["/**/README.md", "/**/model/db"] | ["@gl-database"]
          "DefaultOwners"    | ["/**/README.md", "/**/model/db"] | ["@config-owner @gl-docs"]
          "OverriddenOwners" | ["/**/README.md", "/**/model/db"] | ["@gl-docs"]
        end

        with_them do
          it "assigns the correct paths to each section" do
            expect(file.parsed_data[section].keys).to contain_exactly(*patterns)
            expect(file.parsed_data[section].values.detect { |entry| entry.section != section }).to be_nil
          end

          it "assigns the correct owners for each entry" do
            extracted_owners = file.parsed_data[section].values.collect(&:owner_line).uniq

            expect(extracted_owners).to contain_exactly(*owners)
          end
        end
      end

      it "populates a hash with a single default section" do
        data = file.parsed_data

        expect(data.keys.length).to eq(1)
        expect(data.keys).to contain_exactly(::Gitlab::CodeOwners::Section::DEFAULT)
      end

      context 'when CODEOWNERS file contains sections at the middle of a line' do
        let(:file_content) do
          <<~CONTENT
                [Required]
          *_spec.rb @gl-test

          ^[Optional]
          *_spec.rb @gl-test

          Something before [Partially optional]
          *.md @gl-docs

          Additional content before ^[Another partially optional]
          doc/* @gl-docs
          CONTENT
        end

        it 'parses only sections that start at the beginning of a line' do
          expect(file.parsed_data.keys).to match_array(%w[codeowners Required Optional])
        end
      end

      context "when CODEOWNERS file contains multiple sections" do
        let(:file_content) do
          File.read(Rails.root.join("ee", "spec", "fixtures", "sectional_codeowners_example"))
        end

        it_behaves_like "creates expected parsed sectional results"
      end

      context "when CODEOWNERS file contains multiple sections with mixed-case names" do
        let(:file_content) do
          File.read(Rails.root.join("ee", "spec", "fixtures", "mixed_case_sectional_codeowners_example"))
        end

        it_behaves_like "creates expected parsed sectional results"
      end

      context 'when CODEOWNERS file contains approvals_required' do
        let(:file_content) do
          <<~CONTENT
          [Required][2]
          *_spec.rb @gl-test

          [Another required]
          *_spec.rb @gl-test

          [Required with default owners] @config-owner
          *_spec.rb @gl-test

          ^[Optional][2] @gl-docs @config-owner
          *_spec.rb

          [Required with non-numbers][q]
          *_spec.rb @gl-test

          ^[Optional with non-numbers][.] @not-matching
          *_spec.rb @gl-test
          CONTENT
        end

        it 'parses the approvals_required' do
          entry = file.parsed_data['Required']['/**/*_spec.rb']
          expect(entry.approvals_required).to eq(2)
          expect(entry.owner_line).to eq('@gl-test')

          entry = file.parsed_data['Another required']['/**/*_spec.rb']
          expect(entry.approvals_required).to eq(0)
          expect(entry.owner_line).to eq('@gl-test')

          entry = file.parsed_data['Required with default owners']['/**/*_spec.rb']
          expect(entry.approvals_required).to eq(0)
          expect(entry.owner_line).to eq('@gl-test')

          entry = file.parsed_data['Optional']['/**/*_spec.rb']
          expect(entry.approvals_required).to eq(2)
          expect(entry.owner_line).to eq('@gl-docs @config-owner')

          entry = file.parsed_data['Required with non-numbers']['/**/*_spec.rb']
          expect(entry.approvals_required).to eq(0)
          expect(entry.owner_line).to eq('@gl-test')

          entry = file.parsed_data['Optional with non-numbers']['/**/*_spec.rb']
          expect(entry.approvals_required).to eq(0)
          expect(entry.owner_line).to eq('@gl-test')
        end
      end
    end
  end

  describe '#empty?' do
    subject { file.empty? }

    it { is_expected.to be(false) }

    context 'when there is no content' do
      let(:file_content) { "" }

      it { is_expected.to be(true) }
    end

    context 'when the file is binary' do
      let(:blob) { fake_blob(binary: true) }

      it { is_expected.to be(true) }
    end

    context 'when the file did not exist' do
      let(:blob) { nil }

      it { is_expected.to be(true) }
    end
  end

  describe "#path" do
    context "when the blob exists" do
      it "returns the path to the file" do
        expect(subject.path).to eq(blob.path)
      end
    end

    context "when the blob is nil" do
      let(:blob) { nil }

      it "returns nil" do
        expect(subject.path).to be_nil
      end
    end
  end

  describe '#sections' do
    subject { file.sections }

    context 'when CODEOWNERS file contains sections' do
      let(:file_content) do
        <<~CONTENT
        *.rb @ruby-owner

        [Documentation]
        *.md @gl-docs

        [Test]
        *_spec.rb @gl-test

        [Documentation]
        doc/* @gl-docs
        CONTENT
      end

      it 'returns unique sections' do
        is_expected.to match_array(%w[codeowners Documentation Test])
      end
    end

    context 'when CODEOWNERS file is missing' do
      let(:blob) { nil }

      it 'returns a default section' do
        is_expected.to match_array(['codeowners'])
      end
    end
  end

  describe '#optional_section?' do
    let(:file_content) do
      <<~CONTENT
      *.rb @ruby-owner

      [Required]
      *_spec.rb @gl-test

      ^[Optional]
      *_spec.rb @gl-test

      [Partially optional]
      *.md @gl-docs

      ^[Partially optional]
      doc/* @gl-docs
      CONTENT
    end

    it 'returns whether a section is optional' do
      expect(file.optional_section?('Required')).to be(false)
      expect(file.optional_section?('Optional')).to be(true)
      expect(file.optional_section?('Partially optional')).to be(false)
      expect(file.optional_section?('Does not exist')).to be(false)
    end

    it 'calculates section optionality once', :aggregate_failures do
      required_entry = file.parsed_data['Required'].each_value.first
      optional_entry = file.parsed_data['Optional'].each_value.first

      expect(file.optional_section?('Required')).to be(false)
      expect(file.optional_section?('Optional')).to be(true)

      expect(required_entry).not_to receive(:optional?)
      expect(optional_entry).not_to receive(:optional?)

      expect(file.optional_section?('Required')).to be(false)
      expect(file.optional_section?('Optional')).to be(true)
    end
  end

  describe '#entries_for_path' do
    shared_examples 'entries_for_path behavior' do
      shared_examples_for "returns expected matches" do
        context 'for a path without matches' do
          let(:file_content) do
            <<~CONTENT
            # Simulating a CODOWNERS without entries
            CONTENT
          end

          it 'returns an empty array for an unmatched path' do
            entry = file.entries_for_path('no_matches')

            expect(entry).to be_a Array
            expect(entry).to be_empty
          end
        end

        it 'matches random files to a pattern' do
          entry = file.entries_for_path('app/assets/something.vue').first

          expect(entry.pattern).to eq('*')
          expect(entry.owner_line).to include('default-codeowner')
        end

        it 'uses the last pattern if multiple patterns match' do
          entry = file.entries_for_path('hello.rb').first

          expect(entry.pattern).to eq('*.rb')
          expect(entry.owner_line).to eq('@ruby-owner')
        end

        it 'returns the usernames for a file matching a pattern with a glob' do
          entry = file.entries_for_path('app/models/repository.rb').first

          expect(entry.owner_line).to eq('@ruby-owner')
        end

        it 'allows specifying multiple users' do
          entry = file.entries_for_path('CODEOWNERS').first

          expect(entry.owner_line).to include('multiple', 'owners', 'tab-separated')
        end

        it 'returns emails and usernames for a matched pattern' do
          entry = file.entries_for_path('LICENSE').first

          expect(entry.owner_line).to include('legal', 'janedoe@gitlab.com')
        end

        it 'allows escaping the pound sign used for comments' do
          entry = file.entries_for_path('examples/#file_with_pound.rb').first

          expect(entry.owner_line).to include('owner-file-with-pound')
        end

        it 'returns the usernames for a file nested in a directory' do
          entry = file.entries_for_path('docs/projects/index.md').first

          expect(entry.owner_line).to include('all-docs')
        end

        it 'returns the usernames for a pattern matched with a glob in a folder' do
          entry = file.entries_for_path('docs/index.md').first

          expect(entry.owner_line).to include('root-docs')
        end

        it 'allows matching files nested anywhere in the repository', :aggregate_failures do
          lib_entry = file.entries_for_path('lib/gitlab/git/repository.rb').first
          other_lib_entry = file.entries_for_path('ee/lib/gitlab/git/repository.rb').first

          expect(lib_entry.owner_line).to include('lib-owner')
          expect(other_lib_entry.owner_line).to include('lib-owner')
        end

        it 'allows allows limiting the matching files to the root of the repository', :aggregate_failures do
          config_entry = file.entries_for_path('config/database.yml').first
          other_config_entry = file.entries_for_path('other/config/database.yml').first

          expect(config_entry.owner_line).to include('config-owner')
          expect(other_config_entry.owner_line).to eq('@default-codeowner')
        end

        it 'correctly matches paths with spaces' do
          entry = file.entries_for_path('path with spaces/docs.md').first

          expect(entry.owner_line).to eq('@space-owner')
        end

        context 'paths with whitespaces and username lookalikes' do
          let(:file_content) do
            'a/weird\ path\ with/\ @username\ /\ and-email@lookalikes.com\ / @user-1 email@gitlab.org @user-2'
          end

          it 'parses correctly' do
            entry = file.entries_for_path('a/weird path with/ @username / and-email@lookalikes.com /test.rb').first

            expect(entry.owner_line).to include('user-1', 'user-2', 'email@gitlab.org')
            expect(entry.owner_line).not_to include('username', 'and-email@lookalikes.com')
          end
        end

        context 'a glob on the root directory' do
          let(:file_content) do
            '/* @user-1 @user-2'
          end

          it 'matches files in the root directory' do
            entry = file.entries_for_path('README.md').first

            expect(entry.owner_line).to include('user-1', 'user-2')
          end

          it 'does not match nested files' do
            entry = file.entries_for_path('nested/path/README.md').first

            expect(entry).to be_nil
          end

          context 'partial matches' do
            let(:file_content) do
              'foo/* @user-1 @user-2'
            end

            it 'does not match a file in a folder that looks the same' do
              entry = file.entries_for_path('fufoo/bar').first

              expect(entry).to be_nil
            end

            it 'matches the file in any folder' do
              expect(file.entries_for_path('baz/foo/bar').first.owner_line).to include('user-1', 'user-2')
              expect(file.entries_for_path('/foo/bar').first.owner_line).to include('user-1', 'user-2')
            end
          end
        end
      end

      context 'when handling excluded patterns' do
        let(:file_content) do
          <<~CONTENT
            * @group-x
            !*.rb

            [Ruby]
            *.rb @ruby-devs
            !/config/*
          CONTENT
        end

        before_all do
          group_x = create(:group, name: 'group-x', developers: create(:user))
          create(:project_group_link, project: project, group: group_x)
          ruby_devs = create(:group, name: 'ruby-devs', developers: create(:user))
          create(:project_group_link, project: project, group: ruby_devs)
        end

        before do
          allow(Gitlab::CodeOwners::UserPermissionCheck).to receive(:new).and_return(instance_double(
            Gitlab::CodeOwners::UserPermissionCheck, errors: []))
        end

        it 'matches non-excluded files to default owner' do
          entry = file.entries_for_path('file.txt').first

          expect(entry.owner_line).to eq('@group-x')
        end

        it 'matches .rb files to ruby owner except in config' do
          ruby_entry = file.entries_for_path('app/models/user.rb').first
          config_entry = file.entries_for_path('config/routes.rb')

          expect(ruby_entry.owner_line).to eq('@ruby-devs')
          expect(config_entry).to be_empty
        end

        it 'does not match excluded patterns' do
          entries = file.entries_for_path('config/database.rb')

          expect(entries).to be_empty
        end

        it 'does not require owners for exclusion patterns', :aggregate_failures do
          expect(file.valid?).to be(true)

          expect(file.errors).to be_empty
        end

        context 'with nested exclusions' do
          let(:file_content) do
            <<~CONTENT
              * @group-x

              !/app/temp/*
              !/app/*/temp/*
            CONTENT
          end

          it 'handles nested path exclusions correctly' do
            regular_entry = file.entries_for_path('app/models/user.rb').first
            temp_entry = file.entries_for_path('app/temp/temp.rb')
            nested_temp_entry = file.entries_for_path('app/models/temp/file.rb')

            expect(regular_entry.owner_line).to eq('@group-x')
            expect(temp_entry).to be_empty
            expect(nested_temp_entry).to be_empty
          end
        end
      end

      context 'when a duplicate pattern is redefined after an intervening matching pattern' do
        let(:file_content) do
          <<~CONTENT
            /src/ @team-a
            /src/components/ @frontend
            /src/ @team-b
          CONTENT
        end

        it 'uses the last matching entry (last match wins)' do
          entry = file.entries_for_path('src/components/Button.vue').first

          expect(entry.owner_line).to eq('@team-b')
        end
      end

      context "when CODEOWNERS file contains no sections" do
        it_behaves_like "returns expected matches"
      end

      context "when CODEOWNERS file contains multiple sections" do
        let(:file_content) do
          File.read(Rails.root.join("ee", "spec", "fixtures", "sectional_codeowners_example"))
        end

        it_behaves_like "returns expected matches"
      end
    end

    context 'with optimized pattern matching disabled' do
      before do
        stub_feature_flags(optimized_codeowners_pattern_matching: false)
      end

      it_behaves_like 'entries_for_path behavior'
    end

    context 'with optimized pattern matching enabled' do
      it_behaves_like 'entries_for_path behavior'
    end
  end

  describe '#valid?' do
    context 'when codeowners file has syntax errors' do
      let(:file_content) do
        <<~CONTENT
        *.rb

        []
        *_spec.rb @gl-test

        ^[Optional][5]
        *.txt @user

        [Invalid section

        [OK section header]
        CONTENT
      end

      it 'detects syntax errors' do
        expect(file.valid?).to be(false)

        expect(file.errors).to match_array(
          [
            Gitlab::CodeOwners::Error.new(:missing_entry_owner, 1),
            Gitlab::CodeOwners::Error.new(:missing_section_name, 3),
            Gitlab::CodeOwners::Error.new(:invalid_approval_requirement, 6),
            Gitlab::CodeOwners::Error.new(:invalid_section_format, 9)
          ]
        )
      end

      context 'with malformed owners' do
        context 'when entry owner is invalid' do
          let(:file_content) do
            <<~CONTENT
            # Regular owner
            *.rb @valid-user

            # Just invalid owners
            *.js not_a_user_not_an_email
            CONTENT
          end

          it 'detects the invalid owner' do
            expect(file.valid?).to be(false)

            expect(file.errors).to match_array(
              [
                Gitlab::CodeOwners::Error.new(:malformed_entry_owner, 5)
              ]
            )
          end
        end

        context 'when entry owner is a mix of invalid and valid owners' do
          let(:file_content) do
            <<~CONTENT
              # Regular owner
              *.rb @valid-user

              # Mixed valid and invalid owners
              *.js malformed @valid-user @valid-group another_malformed
            CONTENT
          end

          it 'detects any invalid owner' do
            expect(file.valid?).to be(false)

            expect(file.errors).to match_array(
              [
                Gitlab::CodeOwners::Error.new(:malformed_entry_owner, 5)
              ]
            )
          end
        end
      end
    end

    context 'when the codeowners file does not have syntax errors' do
      let(:file_content) do
        <<~CONTENT
          file1 @reference

          README.md @other_reference
        CONTENT
      end

      it 'calls Gitlab::CodeOwners::OwnerValidation::Process' do
        expect(Gitlab::CodeOwners::OwnerValidation::Process)
          .to receive(:new)
          .with(project, file)
          .and_return(instance_double(Gitlab::CodeOwners::OwnerValidation::Process, execute: nil))

        file.valid?
      end
    end
  end
end
