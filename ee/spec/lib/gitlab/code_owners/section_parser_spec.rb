# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::SectionParser, feature_category: :source_code_management do
  using RSpec::Parameterized::TableSyntax

  subject(:section_parser) { described_class.new(line, sectional_data, line_number) }

  let(:line) { 'line' }
  let(:line_number) { 1 }
  let(:sectional_data) { {} }

  shared_context 'with section header' do
    let(:line) { '[Doc][2] @owner' }
  end

  shared_context 'with entry' do
    let(:line) { '/path/to/file.rb @owner' }
  end

  shared_context 'with invalid section header' do
    let(:line) { '[Doc' }
  end

  describe '#new(line, sectional_data, line_number)' do
    let(:invalid_section_format) { Gitlab::CodeOwners::Error.new(:invalid_section_format, line_number) }
    let(:missing_section_name) { Gitlab::CodeOwners::Error.new(:missing_section_name, line_number) }
    let(:invalid_approval_requirement) { Gitlab::CodeOwners::Error.new(:invalid_approval_requirement, line_number) }
    let(:invalid_section_owner_format) { Gitlab::CodeOwners::Error.new(:invalid_section_owner_format, line_number) }

    where(:line, :name, :optional, :approvals, :default_owners, :sectional_data, :expected_errors) do
      '[Doc]'                       | 'Doc' | false | 0 | ''            | {}              | []
      '[Doc]'                       | 'doc' | false | 0 | ''            | { 'doc' => {} } | []
      '[Doc]'                       | 'Doc' | false | 0 | ''            | { 'foo' => {} } | []
      '^[Doc]'                      | 'Doc' | true  | 0 | ''            | {}              | []
      '[Doc][1]'                    | 'Doc' | false | 1 | ''            | {}              | []
      '[Doc][1] @doc'               | 'Doc' | false | 1 | '@doc'        | {}              | []
      '^[Doc] @doc @rrr.dev @dev'   | 'Doc' | true  | 0 | '@doc @rrr.dev @dev' | {}       | []
      '[Doc][2] @doc @rrr.dev @dev' | 'Doc' | false | 2 | '@doc @rrr.dev @dev' | {}       | []
      '[Doc] @doc'                  | 'Doc' | false | 0 | '@doc'        | {}              | []
      '[Doc] @@developer'           | 'Doc' | false | 0 | '@@developer' | {}              | []
      '[Doc] @@DEVeloper @maintainers @OWNER' | 'Doc' | false | 0 | '@@DEVeloper @maintainers @OWNER' | {} | []
      '[Doc] @doc @rrr.dev @dev'    | 'Doc' | false | 0 | '@doc @rrr.dev @dev' | {}       | []
      '^[Doc] @doc'                 | 'Doc' | true  | 0 | '@doc'        | {}              | []
      '[]'                          | ''    | false | 0 | ''            | {}             | [ref(:missing_section_name)]
      '^[]'                         | ''    | true  | 0 | ''            | {}             | [ref(:missing_section_name)]
      '[][1]'                       | ''    | false | 1 | ''            | {}             | [ref(:missing_section_name)]
      '[][1]@owner'                 | ''    | false | 1 | '@owner'      | {}             | [ref(:missing_section_name)]
      '[Doc][]'                     | 'Doc' | false | 0 | ''            | {}     | [ref(:invalid_approval_requirement)]
      '^[Doc][]'                    | 'Doc' | true  | 0 | ''            | {}     | [ref(:invalid_approval_requirement)]
      '[Doc][] @doc'                | 'Doc' | false | 0 | '@doc'        | {}     | [ref(:invalid_approval_requirement)]
      '[Doc][1 0]'                  | 'Doc' | false | 1 | ''            | {}     | [ref(:invalid_approval_requirement)]
      '^[Doc][1]'                   | 'Doc' | true  | 1 | ''            | {}     | [ref(:invalid_approval_requirement)]
      '^[Doc][1] @doc'              | 'Doc' | true  | 1 | '@doc'        | {}     | [ref(:invalid_approval_requirement)]
      '^[Doc][1] @doc @dev'         | 'Doc' | true  | 1 | '@doc @dev'   | {}     | [ref(:invalid_approval_requirement)]
      '^[Doc][1] @gl/doc-1'         | 'Doc' | true  | 1 | '@gl/doc-1'   | {}     | [ref(:invalid_approval_requirement)]
      '^[Doc][2]@owner'             | 'Doc' | true  | 2 | '@owner'      | {}     | [ref(:invalid_approval_requirement)]
      '[Doc][2] @@dev'              | 'Doc' | false | 2 | '@@dev'       | {}     | [ref(:invalid_section_owner_format)]
      '[Doc] malformed'             | 'Doc' | false | 0 | 'malformed'   | {}     | [ref(:invalid_section_owner_format)]
      '[Doc] @owner oops'           | 'Doc' | false | 0 | '@owner oops' | {}     | [ref(:invalid_section_owner_format)]
      '[Doc] @owner+malformed'      | 'Doc' | false | 0 | '@owner'      | {}           | [ref(:invalid_section_format)]
      '[Doc][1_0]'                  | 'Doc' | false | 0 | ''            | {}           | [ref(:invalid_section_format)]
      '[Doc][one]'                  | 'Doc' | false | 0 | ''            | {}           | [ref(:invalid_section_format)]
      '^[Doc'                       | nil   | nil  | nil | nil          | {}           | [ref(:invalid_section_format)]
      '[Doc'                        | nil   | nil  | nil | nil          | {}           | [ref(:invalid_section_format)]
      '^[Doc]]'                     | 'Doc' | true  | 0 | ''            | {}           | [ref(:invalid_section_format)]
      '[Doc]]'                      | 'Doc' | false | 0 | ''            | {}           | [ref(:invalid_section_format)]
      '^[Doc]] @owner'              | 'Doc' | true  | 0 | ''            | {}           | [ref(:invalid_section_format)]
      '[Doc]] @owner'               | 'Doc' | false | 0 | ''            | {}           | [ref(:invalid_section_format)]
      '[Doc][2]@owner'              | 'Doc' | false | 2 | '@owner'      | {}           | [ref(:invalid_section_format)]
      '[Doc][ 1]'                   | 'Doc' | false | 1 | ''            | {}           | [ref(:invalid_section_format)]
      '[Doc][1 ]'                   | 'Doc' | false | 1 | ''            | {}           | [ref(:invalid_section_format)]
      '[Doc][  1  ]'                | 'Doc' | false | 1 | ''            | {}           | [ref(:invalid_section_format)]
    end

    with_them do
      it 'parses the line', :aggregate_failures do
        section = section_parser.section

        expect(section).to name.nil? ? be_nil : be_present

        if section.present?
          expect(section.name).to eq(name)
          expect(section.optional).to eq(optional)
          expect(section.approvals).to eq(approvals)
          expect(section.default_owners).to eq(default_owners)
        end

        if expected_errors.any?
          expect(section_parser.valid?).to be(false)
          expect(section_parser.errors).to match_array(expected_errors)
        else
          expect(section_parser.valid?).to be(true)
          expect(section_parser.errors).to be_empty
        end
      end
    end
  end

  describe '#errors' do
    subject(:errors) { section_parser.errors }

    it { is_expected.to be_instance_of(Gitlab::CodeOwners::Errors) }
  end

  describe '#section' do
    subject { section_parser.section }

    context 'when line is a section header' do
      include_context 'with section header'

      it { is_expected.to be_instance_of(Gitlab::CodeOwners::Section) }
    end

    context 'when line is an entry' do
      include_context 'with entry'

      it { is_expected.to be_nil }
    end

    context 'when line is an invalid section header' do
      include_context 'with invalid section header'

      it { is_expected.to be_nil }
    end
  end

  describe '#section_header?' do
    subject { section_parser.section_header? }

    context 'when line is a section header' do
      include_context 'with section header'

      it { is_expected.to be(true) }
    end

    context 'when line is an entry' do
      include_context 'with entry'

      it { is_expected.to be(false) }
    end

    context 'when line is an invalid section header' do
      include_context 'with invalid section header'

      it { is_expected.to be(false) }
    end
  end

  describe '#unparsable_section_header?' do
    subject { section_parser.unparsable_section_header? }

    context 'when line is a section header' do
      include_context 'with section header'

      it { is_expected.to be(false) }
    end

    context 'when line is an entry' do
      include_context 'with entry'

      it { is_expected.to be(false) }
    end

    context 'when line is an invalid section header' do
      include_context 'with invalid section header'

      it { is_expected.to be(true) }
    end
  end

  describe '#valid?' do
    let(:errors) { Gitlab::CodeOwners::Errors.new }

    before do
      allow(section_parser).to receive(:errors).and_return(errors)
    end

    context 'when errors are not present' do
      it { is_expected.to be_valid }
    end

    context 'when errors are present' do
      before do
        errors.add(:error, 1)
      end

      it { is_expected.not_to be_valid }
    end
  end
end
