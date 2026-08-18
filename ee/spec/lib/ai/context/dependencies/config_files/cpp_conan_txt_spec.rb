# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::CppConanTxt, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('cpp')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        [requires]
        libiconv/1.17
        openssl/3.2.2u # An inline comment
        poco/[>1.0,<1.9]
        # A comment-only line
        zlib/1.2.13#revision1
        boost/1.67.0@conan/stable

        [generators]
        cmake_find_package_multi

        [options]
        pkg/openssl:shared=False
      CONTENT
    end

    let(:expected_formatted_lib_names) do
      [
        'libiconv (1.17)',
        'openssl (3.2.2)',
        'poco (>1.0,<1.9)',
        'zlib (1.2.13)',
        'boost (1.67.0)'
      ]
    end
  end

  it_behaves_like 'parsing an invalid dependency config file'

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'conanfile.txt'            | true
      'dir/conanfile.txt'        | true
      'dir/subdir/conanfile.txt' | true
      'dir/conanfile'            | false
      'xconanfile.txt'           | false
      'Conanfile.txt'            | false
      'conanfile_txt'            | false
      'conanfile'                | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
