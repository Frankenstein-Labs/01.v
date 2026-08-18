# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::StreamedResponseModifier, feature_category: :shared do
  let(:chunk_id) { { chunk_id: 1 } }
  let(:content) { "content" }

  subject { described_class.new(content, chunk_id).response_body }

  context 'when there is an error' do
    subject { described_class.new(content, nil).errors }

    it { is_expected.to eq [] }
  end

  context 'when successful' do
    it { is_expected.to eq "content" }

    context 'when chunk_id is nil' do
      let(:chunk_id) { nil }

      it { is_expected.to eq "content" }
    end

    context 'when cleaning prefixes' do
      context 'when cleaning ` : ` before the first chunk' do
        let(:content) { " : Hello " }

        it { is_expected.to eq "Hello " }
      end

      context 'when cleaning `: ` before the first chunk' do
        let(:content) { ": Hello " }

        it { is_expected.to eq "Hello " }
      end

      context 'when cleaning ` Answer: ` from the first chunk' do
        let(:content) { " Answer: Hello" }

        it { is_expected.to eq "Hello" }
      end

      context 'when the first chunk is just ` Answer: `' do
        let(:content) { " Answer: " }

        it { is_expected.to eq "" }
      end

      context 'when cleaning text containing `Answer: ` and keeping a trailing space' do
        let(:content) { " Answer: Hello " }

        it { is_expected.to eq "Hello " }
      end

      context 'when cleaning `Final Answer: ` from the first chunk' do
        let(:content) { "Final Answer: Hello" }

        it { is_expected.to eq "Hello" }
      end

      context 'when it is not the first chunk' do
        let(:chunk_id) { { chunk_id: 2 } }
        let(:content) { " Answer: Hello " }

        it { is_expected.to eq " Answer: Hello " }
      end
    end
  end
end
