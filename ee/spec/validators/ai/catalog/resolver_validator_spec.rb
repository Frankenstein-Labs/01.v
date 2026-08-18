# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ai::Catalog::ResolverValidator, feature_category: :duo_agent_platform do
  def define_model_with_keywords(keywords)
    klass = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations

      attr_accessor :resolver
    end

    klass.validates :resolver, "ai/catalog/resolver": { keywords: keywords }
    klass
  end

  describe '#validate_each' do
    subject(:record) { define_model_with_keywords([:project, :goal]).new(resolver: resolver) }

    shared_examples_for 'valid record' do
      it { is_expected.to be_valid }
    end

    shared_examples_for 'invalid record' do
      it 'is invalid', :aggregate_failures do
        expect(record).to be_invalid
        expect(record.errors.messages).to eq(
          resolver: ['must be nil or a lambda accepting keyword arguments: goal, project']
        )
      end
    end

    context 'when the resolver is nil' do
      include_examples 'valid record' do
        let(:resolver) { nil }
      end
    end

    context 'when the resolver accepts the correct keywords' do
      let(:resolver) { ->(project:, goal:) {} }

      include_examples 'valid record'
    end

    context 'when the resolver accepts the correct keywords in a different order' do
      let(:resolver) { ->(goal:, project:) {} }

      include_examples 'valid record'
    end

    context 'when the resolver is missing a required keyword' do
      let(:resolver) { ->(project:) {} }

      include_examples 'invalid record'
    end

    context 'when the resolver has an extra keyword argument' do
      let(:resolver) { ->(project:, goal:, extra:) {} }

      include_examples 'invalid record'
    end

    context 'when the resolver has an optional keyword argument' do
      let(:resolver) { ->(project:, goal: nil) {} }

      include_examples 'invalid record'
    end

    context 'when the resolver takes positional arguments' do
      let(:resolver) { ->(project, goal) {} }

      include_examples 'invalid record'
    end

    context 'when the resolver is a non-lambda proc' do
      let(:resolver) { proc { |project:, goal:| } }

      include_examples 'invalid record'
    end

    context 'when the resolver is not callable' do
      let(:resolver) { 'not-a-lambda' }

      include_examples 'invalid record'
    end
  end

  describe '#check_validity!' do
    subject(:model) { define_model_with_keywords(keywords) }

    shared_examples_for 'does not raise errors' do
      it 'does not raise errors' do
        expect { model }.not_to raise_error
      end
    end

    shared_examples_for 'raises an error' do
      it 'raises an error' do
        expect { model }.to raise_error(ArgumentError, /`:keywords` must be an `Array\[Symbol\]`/)
      end
    end

    context 'when keywords is an Array of Symbols' do
      let(:keywords) { [:project, :goal] }

      include_examples 'does not raise errors'
    end

    context 'when keywords is an empty Array' do
      let(:keywords) { [] }

      include_examples 'does not raise errors'
    end

    context 'when keywords is missing' do
      let(:keywords) { nil }

      include_examples 'raises an error'
    end

    context 'when keywords is not an Array' do
      let(:keywords) { :project }

      include_examples 'raises an error'
    end

    context 'when keywords contains non-Symbol elements' do
      let(:keywords) { ['project', :goal] }

      include_examples 'raises an error'
    end
  end
end
