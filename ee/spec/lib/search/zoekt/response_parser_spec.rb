# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::ResponseParser, feature_category: :global_search do
  using RSpec::Parameterized::TableSyntax

  # Create a simple test class that includes the module
  let(:test_class) do
    Class.new do
      include Search::Zoekt::ResponseParser
    end
  end

  let(:parser) { test_class.new }

  describe '#extract_project_id' do
    where(:description, :file_data, :expected_result) do
      'RepositoryID present and non-zero'                              | { RepositoryID: '12345',
Repository: '67890' } | 12345
      'RepositoryID is zero, fallback to Repository'                   | { RepositoryID: '0',
Repository: '5000000000' }    | 5_000_000_000
      'RepositoryID is missing, use Repository'                        | { Repository: '42' } | 42
      'RepositoryID is nil, fallback to Repository'                    | { RepositoryID: nil,
Repository: '999' }           | 999
      'both fields are missing'                                        | {} | 0
      'both fields are zero'                                           | { RepositoryID: '0',
Repository: '0' }             | 0
      'project ID larger than uint32 max'                              | { RepositoryID: '0',
Repository: '5000000000' }    | 5_000_000_000
      'fields are integers instead of strings'                         | { RepositoryID: 123,
Repository: 456 }             | 123
      'numeric but Repository is preferred when RepositoryID is zero'  | { RepositoryID: 0,
Repository: 789 } | 789
      'symbol keys with RepositoryID preferred'                        | { RepositoryID: '100',
Repository: '200' } | 100
    end

    with_them do
      it 'returns the expected project ID' do
        expect(parser.extract_project_id(file_data)).to eq(expected_result)
      end
    end
  end
end
