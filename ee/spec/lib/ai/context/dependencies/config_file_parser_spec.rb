# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFileParser, feature_category: :code_suggestions do
  let(:config_file_parser) { described_class.new(project) }

  describe '#extract_config_files' do
    subject(:extract_config_files) { config_file_parser.extract_config_files }

    context 'when the repository does not contain a dependency config file' do
      let_it_be(:project) do
        create(:project, :custom_repo, files:
          {
            'a.txt' => 'foo',
            'dir1/b.rb' => 'bar'
          })
      end

      it 'returns an empty array' do
        expect(extract_config_files).to eq([])
      end
    end

    context 'when the repository contains dependency config files' do
      let_it_be(:project) do
        create(:project, :custom_repo, files:
          {
            'a.txt' => 'foo',
            'pom.xml' => '', # Only one of the two pom.xml files is processed
            'dir1/pom.xml' => '',
            'dir1/dir2/go.mod' => # Valid go.mod file
              <<~CONTENT,
                require abc.org/mylib v1.3.0
                require golang.org/x/mod v0.5.0
                require github.com/pmezard/go-difflib v1.0.0 // indirect
              CONTENT
            'dir1/dir2/dir3/Gemfile.lock' => # Valid Gemfile.lock but path is too deep
              <<~CONTENT
                GEM
                  remote: https://rubygems.org/
                  specs:
                    bcrypt (3.1.20)
              CONTENT
          })
      end

      it 'returns config file objects up to MAX_DEPTH with the expected attributes' do
        expect(config_files_array).to contain_exactly(
          {
            lang: 'java',
            valid: false,
            error_message: 'Error while parsing file `dir1/pom.xml`: file empty',
            payload: nil
          },
          {
            lang: 'go',
            valid: true,
            error_message: nil,
            payload: a_hash_including(
              file_path: 'dir1/dir2/go.mod',
              libs: contain_exactly({ name: 'abc.org/mylib (1.3.0)' }, { name: 'golang.org/x/mod (0.5.0)' }))
          }
        )
      end

      context 'with a config file that supports multiple languages' do
        let_it_be(:project) do
          create(:project, :custom_repo, files:
            {
              'dir1/dir2/conanfile.txt' =>
                <<~CONTENT
                  [requires]
                  libiconv/1.17
                  poco/[>1.0,<1.9]
                CONTENT
            })
        end

        it 'returns a config file object for each supported language' do
          expect(config_files_array).to contain_exactly(
            {
              lang: 'c',
              valid: true,
              error_message: nil,
              payload: a_hash_including(
                file_path: 'dir1/dir2/conanfile.txt',
                libs: contain_exactly({ name: 'libiconv (1.17)' }, { name: 'poco (>1.0,<1.9)' }))
            },
            {
              lang: 'cpp',
              valid: true,
              error_message: nil,
              payload: a_hash_including(
                file_path: 'dir1/dir2/conanfile.txt',
                libs: contain_exactly({ name: 'libiconv (1.17)' }, { name: 'poco (>1.0,<1.9)' }))
            }
          )
        end
      end

      context 'with files matching multiple config file classes for the same language' do
        let_it_be(:project) do
          create(:project, :custom_repo, files:
            {
              'pom.xml' =>
                <<~CONTENT,
                  <project>
                      <dependencies>
                          <dependency>
                              <groupId>org.junit.jupiter</groupId>
                              <artifactId>junit-jupiter-engine</artifactId>
                              <version>1.2.0</version>
                          </dependency>
                      </dependencies>
                  </project>
                CONTENT
              'dir1/dir2/build.gradle' =>
                <<~CONTENT
                  dependencies {
                      implementation 'org.codehaus.groovy:groovy:3.+'
                      "implementation" 'org.ow2.asm:asm:9.6'
                  }
                CONTENT
            })
        end

        it 'returns an object of only the first matching config file class in the order of `CONFIG_FILE_CLASSES`' do
          expect(config_files_array).to contain_exactly(
            {
              lang: 'java',
              valid: true,
              error_message: nil,
              payload: a_hash_including(
                file_path: 'dir1/dir2/build.gradle',
                libs: contain_exactly({ name: 'groovy (3.+)' }, { name: 'asm (9.6)' }))
            }
          )
        end
      end

      context 'with multiple files matching the same config file class' do
        context 'when the config file class does not support multiple files' do
          let_it_be(:project) do
            create(:project, :custom_repo, files:
              {
                'go.mod' =>
                  <<~CONTENT,
                    require abc.org/mylib v1.3.0
                  CONTENT
                'dir1/dir2/go.mod' =>
                  <<~CONTENT
                    require golang.org/x/mod v0.5.0
                  CONTENT
              })
          end

          it 'returns a config file object for only one of the matching files' do
            # We can't be sure which file is found first because it depends on the order of the worktree paths
            expect(config_files_array.size).to eq(1)
          end
        end

        context 'when the config file class supports multiple files' do
          let_it_be(:project) do
            create(:project, :custom_repo, files:
              {
                'requirements.txt' =>
                  <<~CONTENT,
                    requests>=2.0,<3.0
                    numpy==1.26.4
                    -r dir1/dir2/dev-requirements.txt
                  CONTENT
                'dir1/dir2/dev-requirements.txt' =>
                  <<~CONTENT
                    python_dateutil>=2.5.3
                    fastapi-health!=0.3.0
                  CONTENT
              })
          end

          it 'returns a config file object for each matching file' do
            expect(config_files_array).to contain_exactly(
              {
                lang: 'python',
                valid: true,
                error_message: nil,
                payload: a_hash_including(
                  file_path: 'requirements.txt',
                  libs: contain_exactly({ name: 'requests (>=2.0,<3.0)' }, { name: 'numpy (==1.26.4)' }))
              },
              {
                lang: 'python',
                valid: true,
                error_message: nil,
                payload: a_hash_including(
                  file_path: 'dir1/dir2/dev-requirements.txt',
                  libs: contain_exactly({ name: 'python_dateutil (>=2.5.3)' }, { name: 'fastapi-health (!=0.3.0)' }))
              }
            )
          end
        end
      end
    end
  end

  private

  def config_files_array
    extract_config_files.map do |config_file|
      {
        lang: config_file.class.lang,
        valid: config_file.valid?,
        error_message: config_file.error_message,
        payload: config_file.payload
      }
    end
  end
end
