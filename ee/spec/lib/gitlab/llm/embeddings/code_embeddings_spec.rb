# frozen_string_literal: true

require 'fast_spec_helper'
require 'httparty'

RSpec.describe Gitlab::Llm::Embeddings::CodeEmbeddings, :aggregate_failures, feature_category: :code_suggestions do
  let(:model_definition) do
    instance_double(
      Gitlab::Llm::Embeddings::ModelDefinition,
      catch_token_limit_exceeded_errors?: false,
      token_limit_exceeded_message_pattern: nil
    )
  end

  let(:input) { ['content one', 'content two', 'content three'] }
  let(:batch_size) { nil }

  subject(:code_embeddings) do
    described_class.new(
      input,
      model_definition: model_definition,
      batch_size: batch_size
    )
  end

  describe '#token_limit_exceeded?' do
    let(:http_response) { instance_double(HTTParty::Response) }
    let(:response) do
      instance_double(
        Gitlab::Llm::Embeddings::Response,
        http_response: http_response,
        error: 'Could not generate embeddings: "the input token count is 9999 but the model supports up to 2048".'
      )
    end

    subject(:token_limit_exceeded) { code_embeddings.send(:token_limit_exceeded?, response) }

    context 'when response is a bad request and model catches token limit errors' do
      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: true,
          token_limit_exceeded_message_pattern: /the input token count is \d+ but the model supports up to \d+/
        )
      end

      before do
        allow(http_response).to receive(:bad_request?).and_return(true)
      end

      it 'returns true' do
        expect(token_limit_exceeded).to be(true)
      end
    end

    context 'when response is not a bad request' do
      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: true,
          token_limit_exceeded_message_pattern: /the input token count is \d+ but the model supports up to \d+/
        )
      end

      before do
        allow(http_response).to receive(:bad_request?).and_return(false)
      end

      it 'returns false' do
        expect(token_limit_exceeded).to be(false)
      end
    end

    context 'when model does not catch token limit errors' do
      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: false,
          token_limit_exceeded_message_pattern: /the input token count is \d+ but the model supports up to \d+/
        )
      end

      before do
        allow(http_response).to receive(:bad_request?).and_return(true)
      end

      it 'returns false' do
        expect(token_limit_exceeded).to be(false)
      end
    end

    context 'when error does not match the pattern' do
      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: true,
          token_limit_exceeded_message_pattern: /different pattern/
        )
      end

      let(:response) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          http_response: http_response,
          error: 'Some other error message'
        )
      end

      before do
        allow(http_response).to receive(:bad_request?).and_return(true)
      end

      it 'returns false' do
        expect(token_limit_exceeded).to be(false)
      end
    end

    context 'when http_response is nil' do
      let(:response) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          http_response: nil,
          error: 'Could not generate embeddings: \"the input token count is 9999 but the model supports up to 2048\".'
        )
      end

      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: true,
          token_limit_exceeded_message_pattern: /the input token count is \d+ but the model supports up to \d+/
        )
      end

      it 'returns false' do
        expect(token_limit_exceeded).to be false
      end
    end
  end

  describe '#execute' do
    let(:client) { instance_double(Gitlab::Llm::Embeddings::Client) }

    let(:embeddings) { [[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]] }
    let(:successful_response) do
      instance_double(
        Gitlab::Llm::Embeddings::Response,
        success?: true,
        embeddings: embeddings,
        http_response: nil,
        error: nil
      )
    end

    before do
      allow(Gitlab::Llm::Embeddings::Client).to receive(:new)
        .with(user: nil, root_namespace_id: nil).and_return(client)
      allow(client).to receive(:code_embeddings).and_return(successful_response)
    end

    context 'when batch_size is nil' do
      let(:batch_size) { nil }

      it 'sends all contents in a single request' do
        expect(client).to receive(:code_embeddings).with(
          contents: input,
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).once

        result = code_embeddings.execute
        expect(result).to eq(embeddings)
      end
    end

    context 'when batch_size is set' do
      let(:batch_size) { 2 }

      it 'sends contents in batches' do
        first_batch_response = instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: true,
          embeddings: [[0.1, 0.2], [0.3, 0.4]],
          http_response: nil,
          error: nil
        )
        second_batch_response = instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: true,
          embeddings: [[0.5, 0.6]],
          http_response: nil,
          error: nil
        )

        expect(client).to receive(:code_embeddings).with(
          contents: ['content one', 'content two'],
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).and_return(first_batch_response)

        expect(client).to receive(:code_embeddings).with(
          contents: ['content three'],
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).and_return(second_batch_response)

        result = code_embeddings.execute
        expect(result).to eq([[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]])
      end
    end

    context 'when the response is unsuccessful' do
      let(:error_response) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: false,
          http_response: instance_double(HTTParty::Response, bad_request?: false),
          error: 'Could not generate embeddings: "some error".'
        )
      end

      before do
        allow(client).to receive(:code_embeddings).and_return(error_response)
      end

      it 'raises an EmbeddingsGenerationError' do
        expect { code_embeddings.execute }.to raise_error(
          described_class::EmbeddingsGenerationError,
          'Could not generate embeddings: "some error".'
        )
      end
    end

    context 'when token limit is exceeded for a batch of more than 1' do
      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: true,
          token_limit_exceeded_message_pattern: /the input token count is \d+ but the model supports up to \d+/
        )
      end

      let(:input) { ['content one', 'content two'] }
      let(:batch_size) { nil }

      let(:token_limit_response) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: false,
          http_response: instance_double(HTTParty::Response, bad_request?: true),
          error: 'Could not generate embeddings: "the input token count is 9999 but the model supports up to 2048".',
          embeddings: nil
        )
      end

      let(:single_embedding_response_1) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: true,
          embeddings: [[0.1, 0.2]],
          http_response: nil,
          error: nil
        )
      end

      let(:single_embedding_response_2) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: true,
          embeddings: [[0.3, 0.4]],
          http_response: nil,
          error: nil
        )
      end

      it 'splits the batch and retries' do
        expect(client).to receive(:code_embeddings).with(
          contents: ['content one', 'content two'],
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).and_return(token_limit_response)

        expect(client).to receive(:code_embeddings).with(
          contents: ['content one'],
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).and_return(single_embedding_response_1)

        expect(client).to receive(:code_embeddings).with(
          contents: ['content two'],
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).and_return(single_embedding_response_2)

        result = code_embeddings.execute
        expect(result).to eq([[0.1, 0.2], [0.3, 0.4]])
      end
    end

    context 'when token limit is exceeded for a single content input' do
      let(:model_definition) do
        instance_double(
          Gitlab::Llm::Embeddings::ModelDefinition,
          catch_token_limit_exceeded_errors?: true,
          token_limit_exceeded_message_pattern: /the input token count is \d+ but the model supports up to \d+/
        )
      end

      let(:input) { ['very long content'] }
      let(:batch_size) { nil }

      let(:token_limit_response) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: false,
          http_response: instance_double(HTTParty::Response, bad_request?: true),
          error: 'Could not generate embeddings: "the input token count is 9999 but the model supports up to 2048".',
          embeddings: nil
        )
      end

      before do
        allow(client).to receive(:code_embeddings).and_return(token_limit_response)
      end

      it 'raises an EmbeddingsGenerationError' do
        expect { code_embeddings.execute }.to raise_error(
          described_class::EmbeddingsGenerationError,
          'token limit exceeded for single content input'
        )
      end
    end

    context 'when input is a single string (not an array)' do
      let(:input) { 'single content' }
      let(:single_embedding_response) do
        instance_double(
          Gitlab::Llm::Embeddings::Response,
          success?: true,
          embeddings: [[0.1, 0.2]],
          http_response: nil,
          error: nil
        )
      end

      it 'wraps the string in an array and processes it' do
        expect(client).to receive(:code_embeddings).with(
          contents: ['single content'],
          model_definition: model_definition,
          search: false,
          dimensions: nil
        ).and_return(single_embedding_response)

        result = code_embeddings.execute
        expect(result).to eq([[0.1, 0.2]])
      end
    end

    context 'for search operations' do
      subject(:code_embeddings) do
        described_class.new(
          input,
          model_definition: model_definition,
          search: true
        )
      end

      it 'sends search=true parameter to the client' do
        expect(client).to receive(:code_embeddings).with(
          contents: input,
          model_definition: model_definition,
          search: true,
          dimensions: nil
        )

        result = code_embeddings.execute
        expect(result).to eq(embeddings)
      end
    end

    context 'with dimensions' do
      subject(:code_embeddings) do
        described_class.new(
          input,
          model_definition: model_definition,
          dimensions: 32
        )
      end

      it 'sends the dimensions parameter to the client' do
        expect(client).to receive(:code_embeddings).with(
          contents: input,
          model_definition: model_definition,
          search: false,
          dimensions: 32
        )

        result = code_embeddings.execute
        expect(result).to eq(embeddings)
      end
    end

    context 'when user is provided' do
      let(:user) { double }

      subject(:code_embeddings) do
        described_class.new(
          input,
          model_definition: model_definition,
          user: user,
          batch_size: batch_size
        )
      end

      it 'builds the client with the user' do
        expect(Gitlab::Llm::Embeddings::Client).to receive(:new)
          .with(user: user, root_namespace_id: nil).and_return(client)

        result = code_embeddings.execute
        expect(result).to eq(embeddings)
      end
    end

    context 'when root_namespace_id is provided' do
      let(:root_namespace_id) { 123 }

      subject(:code_embeddings) do
        described_class.new(
          input,
          model_definition: model_definition,
          root_namespace_id: root_namespace_id,
          batch_size: batch_size
        )
      end

      it 'builds the client with the root_namespace_id' do
        expect(Gitlab::Llm::Embeddings::Client).to receive(:new)
          .with(user: nil, root_namespace_id: root_namespace_id).and_return(client)

        result = code_embeddings.execute
        expect(result).to eq(embeddings)
      end
    end
  end
end
