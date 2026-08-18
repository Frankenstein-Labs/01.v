# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::CppConanPy, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('cpp')
  end

  context 'when dependencies are defined with `self.requires`' do
    it_behaves_like 'parsing a valid dependency config file' do
      let(:config_file_content) do
        <<~CONTENT
          class SampleConan(ConanFile):
              other_lib = "my_other_lib"
              version = "1.2.3"

              def requirements(self):
                  self.requires("fmt/6.0.0@bin/stable")
                  self.requires("libiconv/1.17")
                  self.requires("poco/[>1.0 <1.9]") # Range of versions specified
                  self.requires("glog/0.5.0#revision1")
                  self.requires("protobuf/3.21.12", visible=True) # With additional param

                  # String interpolation is not supported; below outputs nil as version
                  self.requires("my_lib/{}".format(version))
                  # Where the library name must be interpolated, the entire line is ignored
                  self.requires("{}/3.0.0".format(other_lib))

                  if (self.condition):
                      self.requires("zlib")

              def build(self):
                  print("Quoted string that should not be parsed")
                  cmake = self._cmake_configure()
                  cmake.build()
        CONTENT
      end

      let(:expected_formatted_lib_names) do
        [
          'fmt (6.0.0)',
          'libiconv (1.17)',
          'poco (>1.0 <1.9)',
          'glog (0.5.0)',
          'protobuf (3.21.12)',
          'my_lib',
          'zlib'
        ]
      end
    end
  end

  context 'when dependencies are defined with `requires =`' do
    using RSpec::Parameterized::TableSyntax

    where do
      {
        'single line tuple' => {
          content: <<~CONTENT,
            requires=("boost/1.76.0", "fmt/6.0.0@bin/stable")
          CONTENT
          lib_names: ['boost (1.76.0)', 'fmt (6.0.0)']
        },
        'single line tuple, with comment' => {
          content: <<~CONTENT,
            requires = ("glog/0.5.0#revision1") # My comment
          CONTENT
          lib_names: ['glog (0.5.0)']
        },
        'single line tuple, without brackets' => {
          content: <<~CONTENT,
            requires  =  "protobuf/3.21.12", "fmt/6.0.0@bin/stable"
          CONTENT
          lib_names: ['protobuf (3.21.12)', 'fmt (6.0.0)']
        },
        'single line list' => {
          content: <<~CONTENT,
            requires = ["boost/1.76.0", "fmt"]
          CONTENT
          lib_names: ['boost (1.76.0)', 'fmt']
        },
        'multi-line tuple' => {
          content: <<~CONTENT,
            requires=(
              "boost/1.76.0",
              "poco/[>1.0 <1.9]"
            )
          CONTENT
          lib_names: ['boost (1.76.0)', 'poco (>1.0 <1.9)']
        },
        'multi-line tuple, with comments' => {
          content: <<~CONTENT,
            requires = ( # A comment
              "boost/1.76.0", # My comment
              "poco/[>1.0 <1.9]",
              # Other comment
              "fmt"
            )
          CONTENT
          lib_names: ['boost (1.76.0)', 'poco (>1.0 <1.9)', 'fmt']
        },
        'multi-line tuple, without brackets' => {
          content: <<~'CONTENT',
            requires = "boost/1.76.0", \
                       "poco/[>1.0 <1.9]"
          CONTENT
          lib_names: ['boost (1.76.0)', 'poco (>1.0 <1.9)']
        },
        'multi-line tuple, without brackets, with comments' => {
          content: <<~'CONTENT',
            requires= "boost/1.76.0", \ # My comment
                      "poco/[>1.0 <1.9]", \
                      # Other comment
                      "fmt"
          CONTENT
          lib_names: ['boost (1.76.0)', 'poco (>1.0 <1.9)', 'fmt']
        },
        'multi-line list' => {
          content: <<~CONTENT,
            requires = [
              "opencv/4.6.0"
            ]
          CONTENT
          lib_names: ['opencv (4.6.0)']
        }
      }
    end

    with_them do
      it_behaves_like 'parsing a valid dependency config file' do
        let(:config_file_content) do
          <<~CONTENT
            class SampleConan(ConanFile):
                #{content}

                def build(self):
                    print("Quoted string that should not be parsed")
                    cmake = self._cmake_configure()
                    cmake.build()
          CONTENT
        end

        let(:expected_formatted_lib_names) { lib_names }
      end
    end
  end

  it_behaves_like 'parsing an invalid dependency config file'

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'conanfile.py'            | true
      'dir/conanfile.py'        | true
      'dir/subdir/conanfile.py' | true
      'dir/conanfile'           | false
      'xconanfile.py'           | false
      'Conanfile.py'            | false
      'conanfile_py'            | false
      'conanfile'               | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
