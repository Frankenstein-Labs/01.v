# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Query, feature_category: :global_search do
  describe 'initialize' do
    it 'instantiates and can read the attributes' do
      instance = described_class.new('test', source: :api)
      expect(instance.query).to eq 'test'
      expect(instance.source).to eq :api
    end

    context 'when source is not passed' do
      it 'instantiates with nil source and can read the attributes' do
        instance = described_class.new('test')
        expect(instance.query).to eq 'test'
        expect(instance.source).to be_nil
      end
    end

    context 'when query is nil' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'query argument can not be nil')
      end
    end

    context 'when query is not passed' do
      it 'raises an exception on instance initialization' do
        expect { described_class.new }.to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
      end
    end
  end

  describe '#formatted_query' do
    using RSpec::Parameterized::TableSyntax

    context 'for exact mode and source is not api' do
      where(:query, :result) do
        ''                              | ''
        'test'                          | 'test'
        '^test.*\b\d+(a|b)[0-9]\sa{3}$' | %q(\^test\.\*\\\b\\\d\+\\(a\|b\\)\[0\-9\]\\\sa\{3\}\$)
        '"foo"'                         | %q(\"foo\")
        'lang:ruby    test'             | 'test lang:ruby'
        'case:no test'                  | 'test case:no'
        'foo:bar test'                  | 'foo\:bar\ test'
        'test    case:auto'             | 'test case:auto'
        'case:no test f:dummy.rb'       | 'test case:no f:dummy.rb'
        'case:no test -f:dummy.rb'      | 'test case:no -f:dummy.rb'
        'case:no file:dummy test'       | 'test case:no file:dummy'
        'case:no -file:dummy test'      | 'test case:no -file:dummy'
        'test case:no file:dummy'       | 'test case:no file:dummy'
        'test sym:foo'                  | 'test sym:foo'
        'sym:foo'                       | 'sym:foo'
        'test extension:rb'             | 'test extension:rb' # No transpilation required when source is not api
      end

      with_them do
        it 'returns correct exact search query' do
          expect(described_class.new(query).formatted_query(:exact)).to eq result
        end
      end
    end

    context 'for regex mode and source is api' do
      where(:query, :result) do
        'test extension:rb'       | 'test file:\.rb$'
        'test -extension:go'      | 'test -file:\.go$'
        'hello filename:foobar'   | 'hello file:(^|/)foobar$'
        'hello filename:bar.js'   | 'hello file:(^|/)bar\.js$'
        'hello filename:*foo.rb'  | 'hello file:(^|/)[^/]*foo\.rb$'
        'hello filename:*foo.*'   | 'hello file:(^|/)[^/]*foo\.[^/]*$'
        'hello filename:*foo*'    | 'hello file:(^|/)[^/]*foo[^/]*$'
        'te.* -path:hello/world'  | 'te.* -file:(?:^|/)hello\/world'
        'test lang:rb'            | 'test lang:rb' # No transpilation required because syntax is exact code search
      end

      with_them do
        it 'returns correct zoekt search query syntax' do
          expect(described_class.new(query, source: :api).formatted_query(:regex)).to eq result
        end
      end
    end

    context 'for unsupported search mode' do
      it 'raises an exception' do
        expect { described_class.new('test').formatted_query(:dummy) }.to raise_error(
          ArgumentError, 'Not a valid search_mode'
        )
      end
    end

    context 'for repo filter' do
      subject(:repo_filter_query) { described_class.new('test   repo:foo', source: :api).formatted_query(:regex) }

      context 'when repo filter is unavailable' do
        before do
          allow(::Search::Zoekt).to receive(:feature_available?).with(:repo_filter_search).and_return(false)
        end

        it 'sends the query as it is without removing extra spaces between keyword and filter' do
          expect(repo_filter_query).to eq 'test   repo:foo'
        end
      end

      context 'when repo filter is available' do
        before do
          allow(::Search::Zoekt).to receive(:feature_available?).with(:repo_filter_search).and_return(true)
        end

        it 'formats the query by removing extra spaces between keyword and filter' do
          expect(repo_filter_query).to eq 'test repo:foo'
        end
      end
    end
  end
end
