# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Context::Dependencies::ConfigFiles::PythonPoetry, feature_category: :code_suggestions do
  it 'returns the expected language value' do
    expect(described_class.lang).to eq('python')
  end

  it_behaves_like 'parsing a valid dependency config file' do
    let(:config_file_content) do
      <<~CONTENT
        [build-system]
        requires = ["poetry-core>=1.0.0"]
        build-backend = "poetry.core.masonry.api"

        [tool.poetry]
        name = "project"
        version = "1.0.0"
        authors = ["Author <author@project.com>"]

        [tool.poetry.dependencies]
        zlib = "^1.2.1"
        cleo = "!=2.1.0"
        tomlkit = ">=0.11.4,<1.0.0"
        poetry-core = { git = "https://github.com/poetry-core.git", branch = "main" } # Version not parsed
        # Long form version specifier
        cachecontrol = { version = ">=0.14.0", extras = ["filecache"] }
        sentry-sdk = { optional = true, version = "<1.5.0" }

        [tool.poetry.dev-dependencies]
        pytest = "^7.0.0"

        [tool.poetry.group.test.dependencies]
        coverage # Inline comment
        pytest-xdist = { version = ">=3.1", extras = ["psutil"] }

        [tool.poetry.group.typing.test-dependencies]
        mypy = "^1.8.0"

        [tool.coverage.report]
        exclude_also = [
            "if TYPE_CHECKING:"
        ]
      CONTENT
    end

    let(:expected_formatted_lib_names) do
      [
        'zlib (^1.2.1)',
        'cleo (!=2.1.0)',
        'tomlkit (>=0.11.4,<1.0.0)',
        'poetry-core',
        'cachecontrol (>=0.14.0)',
        'sentry-sdk (<1.5.0)',
        'pytest (^7.0.0)',
        'coverage',
        'pytest-xdist (>=3.1)',
        'mypy (^1.8.0)'
      ]
    end
  end

  it_behaves_like 'parsing an invalid dependency config file'

  describe '.matches?' do
    using RSpec::Parameterized::TableSyntax

    where(:path, :matches) do
      'pyproject.toml'            | true
      'dir/pyproject.toml'        | true
      'dir/subdir/pyproject.toml' | true
      'dir/pyproject'             | false
      'xpyproject.toml'           | false
      'Pyproject.toml'            | false
      'pyproject_toml'            | false
      'pyproject'                 | false
    end

    with_them do
      it 'matches the file name glob pattern at various directory levels' do
        expect(described_class.matches?(path)).to eq(matches)
      end
    end
  end
end
