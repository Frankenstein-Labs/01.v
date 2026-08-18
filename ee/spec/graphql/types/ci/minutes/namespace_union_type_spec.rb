# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::Minutes::NamespaceUnionType, feature_category: :hosted_runners do
  describe '.resolve_type' do
    context 'when resolving a namespace' do
      it 'resolves to a NamespaceType' do
        namespace = build_stubbed(:namespace)

        resolved_type = described_class.resolve_type(namespace, {})

        expect(resolved_type).to be(Types::NamespaceType)
      end
    end

    context 'when resolving a DeletedNamespace object' do
      it 'resolves to DeletedNamespaceType' do
        deleted_namespace = ::Types::Ci::Minutes::DeletedNamespaceType::DeletedNamespace.new(123)

        resolved_type = described_class.resolve_type(deleted_namespace, {})

        expect(resolved_type).to be(Types::Ci::Minutes::DeletedNamespaceType)
      end
    end

    context 'when resolving any other object' do
      let(:object_resolved) { 'some string' }

      subject(:resolve) { described_class.resolve_type(object_resolved, {}) }

      it 'raises for nil values' do
        expect { resolve }.to raise_error(
          Types::Ci::Minutes::NamespaceUnionType::TypeNotSupportedError
        )
      end
    end
  end

  describe 'configured types' do
    it 'includes the expected possible types' do
      expect(described_class.possible_types).to contain_exactly(
        Types::NamespaceType,
        Types::Ci::Minutes::DeletedNamespaceType
      )
    end
  end

  describe 'union definition' do
    it 'has the correct graphql_name' do
      expect(described_class.graphql_name).to eq('NamespaceUnion')
    end

    it 'has the correct description' do
      expect(described_class.description).to eq('Represents either a namespace or a reference to a deleted namespace')
    end
  end
end
