# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Context, feature_category: :code_suggestions do
  describe '#trimmed' do
    let(:ctx) do
      [
        {
          type: 'snippet',
          name: 'helloWorld func',
          content: 'func helloWorld() {\nfmt.Println("Hello world")\n}'
        },
        { type: 'file', name: 'main.go', content: 'package main\n\nfunc main() {}' },
        { type: 'file', name: 'user.go', content: 'package main' },
        {
          type: 'snippet',
          name: 'firstName func',
          content: 'func firstName(first, last string) string {\nreturn fmt.Sprintf("%s %s", first, last)\n}'
        }
      ].map(&:with_indifferent_access)
    end

    subject(:trim_context) { described_class.new(ctx).trimmed }

    context 'when context size is less than limit' do
      it 'returns unchanged context' do
        is_expected.to eq(ctx)
      end
    end

    context 'when context size exceeds the limit' do
      before do
        stub_const('CodeSuggestions::Context::MAX_BODY_SIZE', 85)
      end

      it 'trims context fragments from the end of list' do
        is_expected.to eq(
          [
            {
              type: 'snippet',
              name: 'helloWorld func',
              content: 'func helloWorld() {\nfmt.Println("Hello world")\n}'
            },
            { type: 'file', name: 'main.go', content: 'package main\n\nfunc main() {}' }
          ].map(&:with_indifferent_access)
        )
      end
    end

    context 'when context is nil' do
      let(:ctx) { nil }

      it { is_expected.to be_nil }
    end

    context 'when context is empty' do
      let(:ctx) { [] }

      it { is_expected.to be_empty }
    end
  end
end
