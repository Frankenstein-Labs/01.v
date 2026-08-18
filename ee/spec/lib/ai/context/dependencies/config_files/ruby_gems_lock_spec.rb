# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::RubyGemsLock, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('ruby')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        GEM
          remote: https://rubygems.org/
          specs:
            bcrypt (3.1.20)
            logger (1.5.3)

        PLATFORMS
          ruby

        DEPENDENCIES
          bcrypt (~> 3.1, >= 3.1.14)
          logger (~> 1.5.3)

        BUNDLED WITH
          2.5.16
      CONTENT
    end

    let(:expected_formatted_lib_names) { ['bcrypt (3.1.20)', 'logger (1.5.3)'] }
  end

  it_behaves_like 'parsing an invalid dependency config file'

  context 'when the content contains a merge conflict' do
    it_behaves_like 'parsing an invalid dependency config file' do
      let(:invalid_config_file_content) do
        <<~CONTENT
          GEM
            remote: https://rubygems.org/
            specs:
              bcrypt (3.1.20)
              logger (1.5.3)
          <<<<<<< HEAD
          =======
              solargraph (1.2.3)
          >>>>>>> 83d186c9a3ca327b4c1aea18936043ded82ceb2e

          BUNDLED WITH
            2.5.16
        CONTENT
      end

      let(:expected_error_class_name) { 'ParsingErrors::DeserializationException' }
      let(:expected_error_message) { 'Your gem lockfile contains merge conflicts.' }
    end
  end

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'Gemfile.lock'             | true
      'dir/Gemfile.lock'         | true
      'dir/subdir/Gemfile.lock'  | true
      'dir/Gemfile'              | false
      'xGemfile.lock'            | false
      'gemfile.lock'             | false
      'Gemfile_lock'             | false
      'Gemfile.loc'              | false
      'Gemfile'                  | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
