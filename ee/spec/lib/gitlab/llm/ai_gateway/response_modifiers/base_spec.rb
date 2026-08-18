# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::ResponseModifiers::Base, feature_category: :ai_abstraction_layer do
  let(:ai_response) { %("I'm GitLab Duo") }
  let(:base_modifier) { described_class.new(ai_response) }

  describe '#response_body' do
    it 'returns the response body' do
      expect(base_modifier.response_body).to eq(ai_response)
    end
  end

  describe '#errors' do
    context 'when response was successful' do
      it 'returns an empty array' do
        expect(base_modifier.errors).to eq([])
      end
    end

    context 'when response contains errors' do
      let(:error) { 'Error message' }

      context 'when the detail is an string' do
        let(:ai_response) { { 'detail' => error } }

        it 'returns an array with the error message' do
          expect(base_modifier.errors).to eq([error])
        end
      end

      context 'when the detail is an array' do
        let(:ai_response) { { 'detail' => [{ 'msg' => error }] } }

        it 'returns an array with the error message' do
          expect(base_modifier.errors).to eq([error])
        end
      end
    end
  end
end
