# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Evaluators::ReviewMergeRequest, feature_category: :duo_code_review do
  describe '#execute' do
    subject(:evaluation_response) { described_class.new(user:, tracking_context:, options:).execute }

    let(:user) { build_stubbed(:user) }
    let(:tracking_context) do
      {
        request_id: SecureRandom.uuid,
        action: 'review_merge_request'
      }
    end

    let(:options) do
      {
        mr_title: 'Improve variable naming in calculator module',
        mr_description: 'This MR improves code readability by using more descriptive variable names.',
        diffs: 'RAW_DIFF',
        files_content: {
          'calculator.py' => 'calculator.py.content'
        }
      }
    end

    let(:review_content) do
      <<~REVIEW.squish
        <review>
          <comment file="calculator.py" priority="minor" old_line="3" new_line="3">
            Consider using a more descriptive variable name for the loop iterator to maintain consistency with
            the improved naming convention.
          </comment>
        </review>
      REVIEW
    end

    let(:review_response) do
      instance_double(HTTParty::Response, body: { content: review_content }.to_json, success?: true)
    end

    before do
      allow_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
        allow(client).to receive(:complete_prompt).and_return(review_response)
      end
    end

    it 'executes the AI gateway request' do
      expect(evaluation_response).to eq(review_content)
    end
  end
end
