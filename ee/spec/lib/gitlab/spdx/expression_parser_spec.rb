# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Gitlab::SPDX::ExpressionParser, feature_category: :security_policy_management do
  subject(:result) { described_class.new(expression).parse }

  describe Gitlab::SPDX::ExpressionParser::Node do
    it 'stores attributes via keyword arguments' do
      node = described_class.new(type: :id, value: 'MIT', children: [])

      expect(node).to have_attributes(type: :id, value: 'MIT', children: [])
    end

    it 'raises ArgumentError on positional construction' do
      expect { described_class.new(:id, 'MIT', []) }.to raise_error(ArgumentError)
    end
  end

  describe Gitlab::SPDX::ExpressionParser::ExpressionResult do
    let(:node) { Gitlab::SPDX::ExpressionParser::Node.new(type: :id, value: 'MIT', children: []) }

    it 'stores attributes via keyword arguments' do
      result = described_class.new(node: node, literal: 'MIT')

      expect(result).to have_attributes(node: node, literal: 'MIT')
    end

    it 'raises ArgumentError on positional construction' do
      expect { described_class.new(node, 'MIT') }.to raise_error(ArgumentError)
    end
  end

  describe Gitlab::SPDX::ExpressionParser::Token do
    it 'stores attributes via keyword arguments' do
      token = described_class.new(text: 'MIT', offset: 0, type: :id)

      expect(token).to have_attributes(text: 'MIT', offset: 0, type: :id)
    end

    it 'raises ArgumentError on positional construction' do
      expect { described_class.new('MIT', 0, :id) }.to raise_error(ArgumentError)
    end
  end

  context 'when expression is nil' do
    let(:expression) { nil }

    it 'returns a :literal root node with nil value without invoking the parser' do
      aggregate_failures do
        expect(result.node).to have_attributes(type: :literal, value: nil, children: [])
        expect(result.literal).to be_nil
      end
    end
  end

  context 'with a plain SPDX identifier' do
    let(:expression) { 'MIT' }

    it 'returns an :id root node with the identifier value and the original literal' do
      aggregate_failures do
        expect(result.node).to have_attributes(type: :id, value: 'MIT', children: [])
        expect(result.literal).to eq('MIT')
      end
    end
  end

  context 'with a LicenseRef identifier' do
    let(:expression) { 'LicenseRef-Proprietary' }

    it 'returns an :id root node' do
      expect(result.node).to have_attributes(type: :id, value: 'LicenseRef-Proprietary', children: [])
    end
  end

  context 'with a DocumentRef identifier' do
    let(:expression) { 'DocumentRef-foo:LicenseRef-bar' }

    it 'returns an :id root node' do
      expect(result.node).to have_attributes(type: :id, value: 'DocumentRef-foo:LicenseRef-bar', children: [])
    end
  end

  shared_examples 'an AND expression' do
    it 'returns an :and root node with two :id children' do
      expect(result.node.type).to eq(:and)
      expect(result.node.children).to contain_exactly(
        have_attributes(type: :id, value: 'MIT'),
        have_attributes(type: :id, value: 'Apache-2.0')
      )
    end
  end

  context 'with an uppercase AND expression' do
    let(:expression) { 'MIT AND Apache-2.0' }

    it_behaves_like 'an AND expression'
  end

  context 'with a lowercase and expression' do
    let(:expression) { 'MIT and Apache-2.0' }

    it_behaves_like 'an AND expression'
  end

  context 'with a three-term AND expression' do
    let(:expression) { 'MIT AND Apache-2.0 AND GPL-3.0' }

    it 'produces a left-associative :and tree with all three identifiers reachable' do
      # Left-associativity is a grammar property: (MIT AND Apache-2.0) AND GPL-3.0.
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:and)
        expect(root.children[1]).to have_attributes(type: :id, value: 'GPL-3.0')
        expect(root.children[0].type).to eq(:and)
        expect(root.children[0].children).to contain_exactly(
          have_attributes(type: :id, value: 'MIT'),
          have_attributes(type: :id, value: 'Apache-2.0')
        )
      end
    end
  end

  context 'with a parenthesised AND expression' do
    let(:expression) { '(MIT AND Apache-2.0)' }

    it 'strips the outer parentheses via the parser and returns an :and root node' do
      aggregate_failures do
        expect(result.node.type).to eq(:and)
        expect(result.node.children).to contain_exactly(
          have_attributes(type: :id, value: 'MIT'),
          have_attributes(type: :id, value: 'Apache-2.0')
        )
        expect(result.literal).to eq('(MIT AND Apache-2.0)')
      end
    end
  end

  shared_examples 'an OR expression' do
    it 'returns an :or root node with two :id children' do
      expect(result.node.type).to eq(:or)
      expect(result.node.children).to contain_exactly(
        have_attributes(type: :id, value: 'MIT'),
        have_attributes(type: :id, value: 'Apache-2.0')
      )
    end
  end

  context 'with an uppercase OR expression' do
    let(:expression) { 'MIT OR Apache-2.0' }

    it_behaves_like 'an OR expression'
  end

  context 'with a lowercase or expression' do
    let(:expression) { 'MIT or Apache-2.0' }

    it_behaves_like 'an OR expression'
  end

  shared_examples 'a WITH expression' do |operator_text|
    it 'returns a :with root node with base and exception children, preserving operator casing' do
      expect(result.node).to have_attributes(type: :with, value: operator_text)
      expect(result.node.children[0]).to have_attributes(type: :id, value: 'GPL-2.0-or-later')
      expect(result.node.children[1]).to have_attributes(type: :id, value: 'Bison-exception-2.2')
    end
  end

  context 'with an uppercase WITH expression' do
    let(:expression) { 'GPL-2.0-or-later WITH Bison-exception-2.2' }

    it_behaves_like 'a WITH expression', 'WITH'
  end

  context 'with a lowercase with expression' do
    let(:expression) { 'GPL-2.0-or-later with Bison-exception-2.2' }

    it_behaves_like 'a WITH expression', 'with'
  end

  context 'with a version-range "+" expression' do
    let(:expression) { 'CDDL-1.0+' }

    it 'returns a :plus root node whose value is the full token and literal is the original input' do
      aggregate_failures do
        expect(result.node).to have_attributes(type: :plus, value: 'CDDL-1.0+', children: [])
        expect(result.literal).to eq('CDDL-1.0+')
      end
    end

    it 'allows the checker to derive the base version via chomp' do
      expect(result.node.value.chomp('+')).to eq('CDDL-1.0')
    end
  end

  context 'with a mixed AND+OR expression' do
    let(:expression) { 'MIT AND (Apache-2.0 OR GPL-2.0)' }

    it 'produces a tree with :and at the root and :or as the right child' do
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:and)
        expect(root.children[0]).to have_attributes(type: :id, value: 'MIT')
        expect(root.children[1].type).to eq(:or)
        expect(root.children[1].children).to contain_exactly(
          have_attributes(type: :id, value: 'Apache-2.0'),
          have_attributes(type: :id, value: 'GPL-2.0')
        )
        expect(result.literal).to eq('MIT AND (Apache-2.0 OR GPL-2.0)')
      end
    end
  end

  context 'with a mixed WITH+AND expression' do
    let(:expression) { 'GPL-2.0-or-later WITH Bison-exception-2.2 AND MIT' }

    it 'produces a tree with :and at the root and :with as the left child' do
      # WITH has higher precedence than AND per the SPDX spec.
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:and)
        expect(root.children[0].type).to eq(:with)
        expect(root.children[0].children[0]).to have_attributes(type: :id, value: 'GPL-2.0-or-later')
        expect(root.children[0].children[1]).to have_attributes(type: :id, value: 'Bison-exception-2.2')
        expect(root.children[1]).to have_attributes(type: :id, value: 'MIT')
      end
    end
  end

  context 'with a mixed WITH+OR expression' do
    let(:expression) { 'GPL-2.0-or-later WITH Bison-exception-2.2 OR MIT' }

    it 'produces a tree with :or at the root and :with as the left child' do
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:or)
        expect(root.children[0].type).to eq(:with)
        expect(root.children[1]).to have_attributes(type: :id, value: 'MIT')
      end
    end
  end

  context 'with a full precedence chain (PLUS + WITH + AND + OR)' do
    let(:expression) { 'CDDL-1.0+ WITH LicenseRef-exception AND MIT OR Apache-2.0' }

    it 'produces a tree that reflects the full operator precedence: + > WITH > AND > OR' do
      # Expected parse: ((CDDL-1.0+ WITH LicenseRef-exception) AND MIT) OR Apache-2.0
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:or)
        expect(root.children[1]).to have_attributes(type: :id, value: 'Apache-2.0')

        and_node = root.children[0]
        expect(and_node.type).to eq(:and)
        expect(and_node.children[1]).to have_attributes(type: :id, value: 'MIT')

        with_node = and_node.children[0]
        expect(with_node.type).to eq(:with)
        expect(with_node.children[0]).to have_attributes(type: :plus, value: 'CDDL-1.0+')
        expect(with_node.children[1]).to have_attributes(type: :id, value: 'LicenseRef-exception')
      end
    end
  end

  context 'with a mixed PLUS+AND expression' do
    let(:expression) { 'CDDL-1.0+ AND MIT' }

    it 'produces a tree with :and at the root and :plus as the left child' do
      # "+" is resolved at tokenization time, so CDDL-1.0+ is a single :plus
      # leaf before AND is parsed.
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:and)
        expect(root.children[0]).to have_attributes(type: :plus, value: 'CDDL-1.0+')
        expect(root.children[1]).to have_attributes(type: :id, value: 'MIT')
      end
    end
  end

  context 'with a deeply nested expression' do
    let(:expression) { '(MIT OR Apache-2.0) AND (GPL-2.0 OR LGPL-2.1)' }

    it 'produces a tree with :and at the root and two :or children' do
      root = result.node
      aggregate_failures do
        expect(root.type).to eq(:and)
        expect(root.children[0].type).to eq(:or)
        expect(root.children[0].children).to contain_exactly(
          have_attributes(type: :id, value: 'MIT'),
          have_attributes(type: :id, value: 'Apache-2.0')
        )
        expect(root.children[1].type).to eq(:or)
        expect(root.children[1].children).to contain_exactly(
          have_attributes(type: :id, value: 'GPL-2.0'),
          have_attributes(type: :id, value: 'LGPL-2.1')
        )
      end
    end
  end

  context 'with a truncated expression (parse error)' do
    let(:expression) { 'MIT AND' }

    it 'returns a :literal root node with the original input as value' do
      aggregate_failures do
        expect(result.node).to have_attributes(type: :literal, value: 'MIT AND', children: [])
        expect(result.literal).to eq('MIT AND')
      end
    end
  end

  context 'with a bare + character' do
    let(:expression) { 'MIT + Apache-2.0' }

    it 'returns a :literal root node' do
      expect(result.node.type).to eq(:literal)
    end
  end

  context 'with an unrecognised character' do
    let(:expression) { 'MIT @ Apache-2.0' }

    it 'returns a :literal root node with the original input as value' do
      expect(result.node).to have_attributes(type: :literal, value: 'MIT @ Apache-2.0')
    end
  end

  context 'with an unmatched opening parenthesis' do
    let(:expression) { '(MIT AND Apache-2.0' }

    it 'returns a :literal root node' do
      expect(result.node.type).to eq(:literal)
    end
  end

  context 'with an unmatched closing parenthesis' do
    let(:expression) { 'MIT AND Apache-2.0)' }

    it 'returns a :literal root node' do
      expect(result.node.type).to eq(:literal)
    end
  end

  context 'with mixed-case operator "And"' do
    let(:expression) { 'MIT And Apache-2.0' }

    it 'treats "And" as an identifier token, causing a parse error and :literal fallback' do
      expect(result.node.type).to eq(:literal)
    end
  end

  context 'with mixed-case operator "Or"' do
    let(:expression) { 'MIT Or Apache-2.0' }

    it 'treats "Or" as an identifier token, causing a parse error and :literal fallback' do
      expect(result.node.type).to eq(:literal)
    end
  end

  context 'with mixed-case operator "With"' do
    let(:expression) { 'GPL-2.0-or-later With Bison-exception-2.2' }

    it 'treats "With" as an identifier token, causing a parse error and :literal fallback' do
      expect(result.node.type).to eq(:literal)
    end
  end

  context 'when the expression exceeds the maximum nesting depth' do
    let(:expression) { "#{'(' * 51}MIT#{')' * 51}" }

    it 'returns a :literal root node with the original input as value' do
      aggregate_failures do
        expect(result.node).to have_attributes(type: :literal, value: expression, children: [])
        expect(result.literal).to eq(expression)
      end
    end
  end

  context 'when the expression contains an unrecognised character' do
    it 'raises ParseError with the expression and offset in the message' do
      expect { described_class.new('MIT @ Apache-2.0').send(:tokenize) }
        .to raise_error(Gitlab::SPDX::ExpressionParser::ParseError,
          /Unable to parse expression 'MIT @ Apache-2\.0'.*at offset: 4/)
    end

    it 'raises ParseError for a bare + with the expression and offset in the message' do
      expect { described_class.new('MIT + Apache-2.0').send(:tokenize) }
        .to raise_error(Gitlab::SPDX::ExpressionParser::ParseError,
          /Unable to parse expression 'MIT \+ Apache-2\.0'.*at offset: 4/)
    end
  end

  context 'when the expression is truncated' do
    it 'raises ParseError with the expression in the message' do
      parser = described_class.new('MIT AND')
      parser.send(:tokenize)
      expect { parser.send(:parse_or_expression) }
        .to raise_error(Gitlab::SPDX::ExpressionParser::ParseError, /Unable to parse expression 'MIT AND'/)
    end
  end

  context 'when the nesting depth is exceeded' do
    it 'raises ParseError with a nesting message' do
      expression = "#{'(' * 51}MIT#{')' * 51}"
      parser = described_class.new(expression)
      parser.send(:tokenize)
      expect { parser.send(:parse_or_expression) }
        .to raise_error(Gitlab::SPDX::ExpressionParser::ParseError, /Nesting too deep/)
    end
  end
end
