# frozen_string_literal: true

require 'fast_spec_helper'
require 'httparty'

RSpec.describe Gitlab::Llm::Embeddings::Response, feature_category: :code_suggestions do
  let(:embeddings) do
    [
      [0.1, 0.2, 0.3],
      [0.4, 0.5, 0.6],
      [0.7, 0.8, 0.9]
    ]
  end

  let(:parsed_response) do
    predictions = embeddings.map.with_index do |embedding, index|
      { 'embedding' => embedding, 'index' => index }
    end

    {
      'predictions' => predictions,
      'model' => {
        'engine' => 'litellm_embedding',
        'name' => 'embedding-001'
      }
    }
  end

  let(:body) { parsed_response.to_s }

  let(:success) { true }
  let(:status_code) { 200 }

  let(:http_response) do
    instance_double(
      HTTParty::Response,
      success?: success,
      code: status_code,
      parsed_response: parsed_response,
      body: body
    )
  end

  subject(:response) { described_class.new(http_response) }

  it 'delegates methods to the http_response object' do
    expect(response.success?).to be(success)
    expect(response.status_code).to eq(status_code)
    expect(response.parsed_response).to eq(parsed_response)
  end

  describe '#parsed_response' do
    context 'when http_response is present' do
      it 'returns the parsed_response from http_response' do
        expect(response.parsed_response).to eq(parsed_response)
      end
    end

    context 'when http_response is nil' do
      let(:http_response) { nil }

      it 'returns nil' do
        expect(response.parsed_response).to be_nil
      end
    end
  end

  describe '#embeddings' do
    context 'when response is successful' do
      let(:success) { true }

      it 'returns the list of embeddings' do
        expect(response.embeddings).to eq(embeddings)
      end
    end

    context 'when response is unsuccessful' do
      let(:success) { false }

      it 'returns nil' do
        expect(response.embeddings).to be_nil
      end
    end

    context 'when parsed_response has no predictions' do
      let(:parsed_response) { {} }

      it 'returns an empty array' do
        expect(response.embeddings).to eq([])
      end
    end
  end

  describe '#error' do
    context 'for successful response' do
      let(:success) { true }

      it 'returns nil' do
        expect(response.error).to be_nil
      end
    end

    context 'for unsuccessful response' do
      context 'when `http_response` is nil' do
        let(:http_response) { nil }

        it 'indicates no response' do
          expect(response.error).to eq('embeddings generation had no response')
        end
      end

      context 'when `http_response` is not nil' do
        let(:success) { false }

        context 'when `parsed_response` has a `detail` value' do
          let(:parsed_response) do
            { 'detail' => 'this is a detailed error message' }
          end

          it 'includes detailed error in the message' do
            expect(response.error).to eq(
              "could not generate embeddings: this is a detailed error message"
            )
          end
        end

        context 'when `parsed_response` has no `detail` value' do
          let(:parsed_response) do
            { 'some_key' => 'this is a detailed error message' }
          end

          it 'includes the response body in the error message' do
            expect(response.error).to eq(
              "could not generate embeddings: #{body}"
            )
          end
        end

        context 'when `parsed_response` is `nil`' do
          let(:parsed_response) { nil }
          let(:body) { "this is the response body" }

          it 'includes the response body in the error message' do
            expect(response.error).to eq(
              "could not generate embeddings: #{body}"
            )
          end
        end
      end
    end
  end
end
