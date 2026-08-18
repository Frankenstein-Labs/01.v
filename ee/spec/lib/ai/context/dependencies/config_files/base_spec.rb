# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::Base, feature_category: :code_suggestions do
  using RSpec::Parameterized::TableSyntax

  let(:config_file_class) { ConfigFileClass }

  before do
    stub_const('ConfigFileClass',
      Class.new(described_class) do
        def self.file_name_glob
          'test.json'
        end

        def self.lang_name
          'Go'
        end

        def extract_libs
          parsed = Gitlab::Json.parse(content)
          libs = dig_in(parsed, 'parent_node', 'child_node')
          libs.try(:map) { |hash| self.class::Lib.new(**hash) }
        rescue JSON::ParserError
          raise Ai::Context::Dependencies::ConfigFiles::ParsingErrors::DeserializationException,
            'content is not valid JSON'
        end
      end
    )
  end

  it 'defines the expected interface for child classes' do
    blob = instance_double('Gitlab::Git::Blob', path: 'path/to/configfile', data: 'content')
    project = instance_double('Project', id: 123)

    expect { described_class.file_name_glob }.to raise_error(NotImplementedError)
    expect { described_class.lang_name }.to raise_error(NotImplementedError)
    expect { described_class.new(blob, project).parse! }.to raise_error(NotImplementedError)
    expect(described_class.supports_multiple_files?).to be(false)
  end

  it 'returns the expected language value' do
    expect(config_file_class.lang).to eq('go')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      Gitlab::Json.dump({
        'parent_node' => { 'child_node' => [
          { name: ' lib1 ' },
          { name: 'lib2', version: '2.1.0 ' },
          { name: 'lib3', version: '' },
          { name: 'lib4', version: nil },
          { name: 'lib5', version: 123 },
          { name: 'lib6', version: 1.0 }
        ] }
      })
    end

    let(:expected_formatted_lib_names) { ['lib1', 'lib2 (2.1.0)', 'lib3', 'lib4', 'lib5 (123)', 'lib6 (1.0)'] }
  end

  context 'when a dependency name contains an invalid byte sequence' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:invalid_byte_sequence) { [0xFE, 0x00, 0x00, 0x00].pack('C*') }
      let(:config_file_content) do
        <<~JSON
          {
            "parent_node": {
              "child_node": [
                { "name": "#{invalid_byte_sequence}lib1", "version": "1.0" },
                { "name": "lib2", "version": "2.0" }
              ]
            }
          }
        JSON
      end

      let(:expected_formatted_lib_names) { ['lib1 (1.0)', 'lib2 (2.0)'] }
    end
  end

  it_behaves_like 'parsing an invalid dependency config file' do
    let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
    let(:expected_error_message) { 'content is not valid JSON' }
  end

  context 'when no dependencies are extracted' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '{}' }
      let(:expected_error_class_name) { 'ParsingErrors::UnexpectedFormatOrDependenciesNotPresentError' }
      let(:expected_error_message) { 'unexpected format or dependencies not present' }
    end
  end

  context 'when the content has an unexpected node' do
    where(:content) do
      [
        [{ 'parent_node' => [] }],
        [{ 'parent_node' => 123 }],
        [123],
        [nil]
      ]
    end

    with_them do
      it_behaves_like 'parsing an invalid dependency config file' do
        let(:invalid_config_file_content) { Gitlab::Json.dump(content) }
        let(:expected_error_class_name) { 'ParsingErrors::UnexpectedNodeError' }
        let(:expected_error_message) { 'encountered unexpected node' }
      end
    end
  end

  context 'when the content is empty' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) { '' }
      let(:expected_error_class_name) { 'ParsingErrors::FileEmptyError' }
      let(:expected_error_message) { 'file empty' }
    end
  end

  context 'when a dependency name is an unexpected type or blank' do
    where(:lib_name, :expected_error_class_name, :expected_error_message) do
      ['lib1']   | 'ParsingErrors::UnexpectedDependencyNameTypeError' | 'unexpected dependency name type `Array`'
      { k: 'v' } | 'ParsingErrors::UnexpectedDependencyNameTypeError' | 'unexpected dependency name type `Hash`'
      true       | 'ParsingErrors::UnexpectedDependencyNameTypeError' | 'unexpected dependency name type `TrueClass`'
      nil        | 'ParsingErrors::UnexpectedDependencyNameTypeError' | 'unexpected dependency name type `NilClass`'
      ''         | 'ParsingErrors::BlankDependencyNameError'          | 'dependency name is blank'
      ' '        | 'ParsingErrors::BlankDependencyNameError'          | 'dependency name is blank'
    end

    with_them do
      it_behaves_like 'parsing an invalid dependency config file' do
        let(:invalid_config_file_content) do
          Gitlab::Json.dump({
            'parent_node' => { 'child_node' => [
              { name: 'other-lib', version: '' },
              { name: lib_name, version: '1.0' }
            ] }
          })
        end
      end
    end
  end

  context 'when a dependency version is an unexpected type' do
    where(:lib_version, :expected_error_class_name, :expected_error_message) do
      ['lib1']   | 'ParsingErrors::UnexpectedDependencyVersionTypeError' | 'unexpected dependency version type `Array`'
      { k: 'v' } | 'ParsingErrors::UnexpectedDependencyVersionTypeError' | 'unexpected dependency version type `Hash`'
      true       | 'ParsingErrors::UnexpectedDependencyVersionTypeError' |
        'unexpected dependency version type `TrueClass`'
    end

    with_them do
      it_behaves_like 'parsing an invalid dependency config file' do
        let(:invalid_config_file_content) do
          Gitlab::Json.dump({
            'parent_node' => { 'child_node' => [
              { name: 'other-lib', version: '' },
              { name: 'my-lib', version: lib_version }
            ] }
          })
        end
      end
    end
  end

  describe 'string sanitization and validation' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        Gitlab::Json.dump({
          'parent_node' => { 'child_node' => [
            { name: 'my-lib-1     ', version: nil },
            { name: ' My_LibName2 ', version: 123 },
            { name: 'path.org/lib3', version: 1.0 },
            { name: 'My.Lib.Name4 ', version: ' ' },
            { name: 'lib5 ', version: '1.0.0-alpha ' },
            { name: 'lib6 ', version: ' >1.0 <2.1.0-beta.11 ' },
            { name: 'lib7 ', version: ' >2.0,<3.0.0-0.3.7' },
            { name: 'lib8 ', version: '^1.4.0+2024' },
            { name: 'lib9 ', version: '^10.3.4-rc.1+build.2 || ^11.5.4+meta-data' },
            { name: 'lib10', version: '>=2.3.4+build.sha.45465,<3.0.0-alpha+001' },
            { name: 'lib11', version: '==5.0.0-pre+betaOnly' },
            { name: 'lib12', version: '> 1.4.6-pre.2+exp.3567, == 1.4.*' },
            { name: 'lib13', version: '!=4.3.1postfix' },
            { name: 'lib14', version: '2.2.3u' }
          ] }
        })
      end

      let(:expected_formatted_lib_names) do
        [
          'my-lib-1', 'My_LibName2 (123)', 'path.org/lib3 (1.0)', 'My.Lib.Name4', 'lib5 (1.0.0)', 'lib6 (>1.0 <2.1.0)',
          'lib7 (>2.0,<3.0.0)', 'lib8 (^1.4.0)', 'lib9 (^10.3.4 || ^11.5.4)', 'lib10 (>=2.3.4,<3.0.0)',
          'lib11 (==5.0.0)', 'lib12 (> 1.4.6, == 1.4.*)', 'lib13 (!=4.3.1)', 'lib14 (2.2.3)'
        ]
      end
    end

    context 'when a dependency name contains invalid characters' do
      where(:lib_name) { ['my-lib-', '.lib-name', 'lib@name'] }

      with_them do
        it_behaves_like 'parsing an invalid dependency config file' do
          let(:invalid_config_file_content) do
            Gitlab::Json.dump({
              'parent_node' => { 'child_node' => [
                { name: lib_name, version: '1.0' }
              ] }
            })
          end

          let(:expected_error_class_name) { 'Base::StringValidationError' }
          let(:expected_error_message) { "dependency name `#{lib_name}` contains invalid characters" }
        end
      end
    end

    context 'when a dependency name is too long' do
      before do
        stub_const("#{described_class}::MAX_NAME_LENGTH", 4)
      end

      it_behaves_like 'parsing an invalid dependency config file' do
        let(:invalid_config_file_content) do
          Gitlab::Json.dump({
            'parent_node' => { 'child_node' => [
              { name: 'long-lib-name', version: '1.0' }
            ] }
          })
        end

        let(:expected_error_class_name) { 'Base::StringValidationError' }
        let(:expected_error_message) { 'dependency name `long-...` exceeds 4 characters' }
      end
    end

    context 'when a dependency version contains invalid characters' do
      where(:lib_version) { ['a1.0.0', 'invalid-word', '1.0/2.0'] }

      with_them do
        it_behaves_like 'parsing an invalid dependency config file' do
          let(:invalid_config_file_content) do
            Gitlab::Json.dump({
              'parent_node' => { 'child_node' => [
                { name: 'my-lib', version: lib_version }
              ] }
            })
          end

          let(:expected_error_class_name) { 'Base::StringValidationError' }
          let(:expected_error_message) { "dependency version `#{lib_version}` contains invalid characters" }
        end
      end
    end

    context 'when a dependency version is too long' do
      before do
        stub_const("#{described_class}::MAX_VERSION_LENGTH", 4)
      end

      it_behaves_like 'parsing an invalid dependency config file' do
        let(:invalid_config_file_content) do
          Gitlab::Json.dump({
            'parent_node' => { 'child_node' => [
              { name: 'my-lib', version: '12345.66.77' }
            ] }
          })
        end

        let(:expected_error_class_name) { 'Base::StringValidationError' }
        let(:expected_error_message) { 'dependency version `12345...` exceeds 4 characters' }
      end
    end
  end

  describe '.matches?' do
    where(:path, :matches) do
      'test.json'             | true
      'dir/test.json'         | true
      'dir/subdir/test.json'  | true
      'dir/test'              | false
      'xtest.json'            | false
      'test.jso'              | false
      'test'                  | false
      'unknown'               | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(config_file_class.matches?(path)).to eq(matches)
      end
    end
  end

  describe '.matching_paths' do
    let(:paths) { ['other.rb', 'dir/test.json', 'test.txt', 'test.json', 'README.md'] }

    subject(:matching_paths) { config_file_class.matching_paths(paths) }

    it 'returns the first matching path' do
      expect(matching_paths).to contain_exactly('dir/test.json')
    end

    context 'when multiple files are supported' do
      before do
        stub_const('ConfigFileClass',
          Class.new(described_class) do
            def self.file_name_glob
              'test.json'
            end

            def self.supports_multiple_files?
              true
            end
          end
        )
      end

      it 'returns all matching paths' do
        expect(matching_paths).to contain_exactly('dir/test.json', 'test.json')
      end
    end
  end
end
