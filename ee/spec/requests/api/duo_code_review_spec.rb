# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::DuoCodeReview, feature_category: :duo_code_review do
  let_it_be(:authorized_user) { create(:user) }
  let_it_be(:unauthorized_user) { build(:user) }

  let_it_be(:tokens) do
    {
      api: create(:personal_access_token, scopes: %w[api], user: authorized_user),
      read_api: create(:personal_access_token, scopes: %w[read_api], user: authorized_user),
      ai_features: create(:personal_access_token, scopes: %w[ai_features], user: authorized_user)
    }
  end

  describe 'POST /duo_code_review/evaluations' do
    let(:dev_or_test_env?) { true }
    let(:license_feature_available) { true }
    let(:global_feature_flag_enabled) { true }
    let(:current_user) { authorized_user }
    let(:raw_diffs) do
      <<~DIFFS
        diff --git a/path.md b/path.md
        index 1234567..abcdefg 100644
        --- a/path.md
        +++ b/path.md
        @@ -1,1 +1,1 @@
        -Old content
        +New content
      DIFFS
    end

    let(:mr_title) { 'Test MR Title' }
    let(:mr_description) { 'Test MR Description' }
    let(:files_content) { "# Title\n\nNew content\n\nMore content" }
    let(:headers) { {} }

    let(:body) do
      {
        diffs: raw_diffs,
        mr_title: mr_title,
        mr_description: mr_description,
        files_content: { 'path.md' => files_content }
      }
    end

    let(:review_prompt) { { messages: ['prompt'] } }
    let(:review_response) do
      instance_double(
        HTTParty::Response,
        body: { content: 'Review response' }.to_json,
        success?: true
      )
    end

    subject(:post_api) do
      post api('/duo_code_review/evaluations', current_user), headers: headers, params: body
    end

    before do
      stub_licensed_features(review_merge_request: license_feature_available)
      stub_feature_flags(ai_global_switch: global_feature_flag_enabled)

      allow(Gitlab).to receive(:dev_or_test_env?).and_return(dev_or_test_env?)

      allow_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
        allow(client).to receive(:complete_prompt).and_return(review_response)
      end

      post_api
    end

    it 'returns 201 with the review response' do
      expect(response).to have_gitlab_http_status(:created)
      expect(response.body).to eq({ review: 'Review response' }.to_json)
    end

    context 'when environment is not development or test' do
      let(:dev_or_test_env?) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it { expect(response).to have_gitlab_http_status(:unauthorized) }
    end

    context 'when feature is not available in license' do
      let(:license_feature_available) { false }

      it { expect(response).to have_gitlab_http_status(:not_found) }
    end

    context 'when token is used' do
      let(:current_user) { nil }
      let(:access_token) { tokens[:api] }
      let(:headers) { { 'Authorization' => "Bearer #{access_token.token}" } }

      it { expect(response).to have_gitlab_http_status(:created) }

      context 'when using token with :ai_features scope' do
        let(:access_token) { tokens[:ai_features] }

        it { expect(response).to have_gitlab_http_status(:created) }
      end

      context 'when using token with :read_api scope' do
        let(:access_token) { tokens[:read_api] }

        it { expect(response).to have_gitlab_http_status(:forbidden) }
      end
    end

    context 'when required parameters are missing' do
      context 'when mr_title parameter is missing' do
        let(:body) do
          {
            diffs: raw_diffs,
            mr_description: mr_description,
            files_content: { 'path.md' => files_content }
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when mr_description parameter is missing' do
        let(:body) do
          {
            diffs: raw_diffs,
            mr_title: mr_title,
            files_content: { 'path.md' => files_content }
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when diffs parameter is missing' do
        let(:body) do
          {
            mr_title: mr_title,
            mr_description: mr_description,
            files_content: { 'path.md' => files_content }
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end

      context 'when files_content parameter is missing' do
        let(:body) do
          {
            diffs: raw_diffs,
            mr_title: mr_title,
            mr_description: mr_description
          }
        end

        it { expect(response).to have_gitlab_http_status(:bad_request) }
      end
    end

    context 'when extracting review from response with thinking steps' do
      let(:evaluation_response_with_steps) do
        <<~RESPONSE
        <step1>
        Understanding the context: This MR implements an order orchestration service
        </step1>

        <step2>
        Analyzing the diff thoroughly: The code adds a complete OrderOrchestrator struct
        </step2>

        <review>
        <comment file="internal/services/order_orchestrator.go" old_line="" new_line="26">
        The HTTP client lacks timeout configuration
        </comment>
        </review>
        RESPONSE
      end

      it 'extracts only the final review section, ignoring thinking steps' do
        evaluator_double = instance_double(Gitlab::Llm::Evaluators::ReviewMergeRequest)
        allow(Gitlab::Llm::Evaluators::ReviewMergeRequest).to receive(:new).and_return(evaluator_double)
        allow(evaluator_double).to receive(:execute).and_return(evaluation_response_with_steps)

        post api('/duo_code_review/evaluations', current_user), headers: headers, params: body

        expect(response).to have_gitlab_http_status(:created)

        response_body = ::Gitlab::Json.parse(response.body)
        extracted_review = <<~REVIEW.strip
        <review>
        <comment file="internal/services/order_orchestrator.go" old_line="" new_line="26">
        The HTTP client lacks timeout configuration
        </comment>
        </review>
        REVIEW

        expect(response_body['review']).to eq(extracted_review)
        expect(response_body['review']).not_to include('<step')
      end
    end

    context 'when response has multiple review sections' do
      let(:multiple_review_response) do
        <<~RESPONSE
        Here's an example: <review>example content</review>

        And here's the actual review:
        <review>
        <comment file="test.rb" old_line="5" new_line="10">
        Real comment here#{'  '}
        </comment>
        </review>
        RESPONSE
      end

      it 'extracts only the last review section' do
        evaluator_double = instance_double(Gitlab::Llm::Evaluators::ReviewMergeRequest)
        allow(Gitlab::Llm::Evaluators::ReviewMergeRequest).to receive(:new).and_return(evaluator_double)
        allow(evaluator_double).to receive(:execute).and_return(multiple_review_response)

        post api('/duo_code_review/evaluations', current_user), headers: headers, params: body

        expect(response).to have_gitlab_http_status(:created)

        response_body = ::Gitlab::Json.parse(response.body)
        expected_review = <<~REVIEW.strip
        <review>
        <comment file="test.rb" old_line="5" new_line="10">
        Real comment here#{'  '}
        </comment>
        </review>
        REVIEW

        expect(response_body['review']).to eq(expected_review)
        expect(response_body['review']).not_to include('example content')
      end
    end

    context 'when response has no review tags' do
      it 'returns the original response when no review tags are found' do
        evaluator_double = instance_double(Gitlab::Llm::Evaluators::ReviewMergeRequest)
        allow(Gitlab::Llm::Evaluators::ReviewMergeRequest).to receive(:new).and_return(evaluator_double)
        allow(evaluator_double).to receive(:execute).and_return('Response without review tags')

        post api('/duo_code_review/evaluations', current_user), headers: headers, params: body

        expect(response).to have_gitlab_http_status(:created)
        expect(::Gitlab::Json.parse(response.body)['review']).to eq('Response without review tags')
      end
    end
  end
end
