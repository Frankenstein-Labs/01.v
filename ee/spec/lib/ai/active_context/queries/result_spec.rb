# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::Queries::Result, feature_category: :code_suggestions do
  describe '.success' do
    subject(:result) { described_class.success(hits) }

    let(:hits) do
      [
        { path: 'some/path', content: 'some content' },
        { path: 'dummy/path', content: 'dummy content' }
      ]
    end

    it { expect(result).to be_success }
    it { expect(result.hits).to eq(hits) }
    it { expect(result.each.to_a).to eq(hits) }
    it { expect(result.to_a).to eq(hits) }
  end

  describe 'error result' do
    shared_examples 'failure result' do
      it { expect(result).not_to be_success }
      it { expect(result.error_code).to eq(error_code) }

      it 'raises an error when `each` is called' do
        expect { result.each }.to raise_error(
          described_class::NilHitsError,
          "`hits` is nil. This is likely a failure result, please check `success?`"
        )
      end
    end

    describe '.error' do
      subject(:result) { described_class.error(error_code) }

      let(:error_code) { :some_code }

      it_behaves_like 'failure result'

      it 'returns "Unknown error"' do
        expect(result.error_message(target_class: nil, target_id: nil)).to eq("Unknown error")
      end

      context 'when `error_detail` is provided' do
        subject(:result) { described_class.error(error_code, error_detail: "This is an error") }

        it 'returns the `error_detail` as the message' do
          expect(result.error_message(target_class: nil, target_id: nil)).to eq("This is an error")
        end
      end
    end

    describe '.no_embeddings_error' do
      subject(:result) { described_class.no_embeddings_error }

      it_behaves_like 'failure result' do
        let(:error_code) { described_class::ERROR_NO_EMBEDDINGS }
      end

      it 'returns the expected error message' do
        result_error_message = result.error_message(target_class: "Project", target_id: "some/path")
        expected_error_message = "Project 'some/path' has no embeddings"

        expect(result_error_message).to eq(expected_error_message)
      end

      context 'when `error_detail` is provided' do
        subject(:result) { described_class.no_embeddings_error(error_detail: "check again later") }

        it 'includes the `error_detail` in the error_message' do
          result_error_message = result.error_message(target_class: "Project", target_id: "some/path")
          expected_error_message = "Project 'some/path' has no embeddings - check again later"

          expect(result_error_message).to eq(expected_error_message)
        end
      end
    end

    describe '#error_message' do
      subject(:result) { described_class.no_embeddings_error }

      context 'when given `target_class` and `target_id` are not string' do
        it 'returns the expected error message' do
          result_error_message = result.error_message(target_class: Project, target_id: 123)
          expected_error_message = "Project '123' has no embeddings"

          expect(result_error_message).to eq(expected_error_message)
        end
      end
    end
  end
end
