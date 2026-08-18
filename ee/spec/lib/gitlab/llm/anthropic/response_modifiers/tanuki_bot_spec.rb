# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot, feature_category: :duo_chat do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:current_user) { create(:user) }

  let(:text) { 'some ai response text' }
  let(:ai_response) { { completion: "#{text} ATTRS: CNT-IDX-#{record_id}" }.to_json }
  let(:record_id) { search_documents.first[:id] }

  let(:metadata) { { foo: 'bar', 'filename' => 'baz.md' } }
  let(:search_documents) do
    [
      { id: "abc123", content: '<content>', metadata: metadata },
      { id: "efg456", content: '<content>', metadata: metadata }
    ]
  end

  describe '#response_body' do
    let(:expected_response) { text }

    subject { described_class.new(ai_response, current_user, search_documents: search_documents).response_body }

    it { is_expected.to eq(text) }
  end

  describe '#extras' do
    subject(:result) { described_class.new(ai_response, current_user, search_documents: search_documents).extras }

    let(:ai_response) do
      { completion: "#{text} ATTRS: CNT-IDX-abc123 ATTRS: CNT-IDX-efg456 #{text}" }.to_json
    end

    context 'when the ids match existing documents' do
      it 'fills sources' do
        expect(result).to eq(sources: [{ source_url: 'baz.md', foo: 'bar', filename: 'baz.md' }])
      end
    end

    context "when the ids don't match any documents" do
      let(:search_documents) do
        [
          { id: "xyz789", content: '<content>', metadata: metadata }
        ]
      end

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end

    context "when the there are no ids" do
      let(:ai_response) { { completion: "#{text} ATTRS:" }.to_json }

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end

    context "when there is error in place of ids" do
      let(:ai_response) { { completion: "#{text} ATTRS: error" }.to_json }

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end

    context "when the message contains the text I don't know" do
      let(:text) { "I don't know the answer to your question" }
      let(:record_id) { non_existing_record_id }

      it 'sets extras as empty' do
        expect(subject).to eq(sources: [])
      end
    end
  end
end
