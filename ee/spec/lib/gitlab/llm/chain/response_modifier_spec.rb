# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::ResponseModifier, feature_category: :duo_chat do
  subject { described_class.new(answer) }

  let(:content) { "This is the summary" }
  let(:extras) { [{ foo: 'bar' }] }
  let(:context) { instance_double(Gitlab::Llm::Chain::GitlabContext) }
  let(:status) { :ok }
  let(:error_code) { nil }
  let(:answer) do
    ::Gitlab::Llm::Chain::Answer.new(
      status: status, context: context, content: content, tool: nil, is_final: true, extras: extras,
      error_code: error_code
    )
  end

  context 'on success' do
    it 'has proper response_body and extras' do
      expect(subject.response_body).to eq(content)
      expect(subject.extras).to eq(extras)
    end
  end

  context 'on error' do
    let(:status) { :error }

    it 'fills errors' do
      expect(subject.errors).to eq([content])
    end

    context 'when answer has error code' do
      let(:error_code) { "A1000" }

      it 'appends the error code link to the message' do
        expected_url =
          "#{Gitlab.doc_url}/ee/user/gitlab_duo_chat/troubleshooting.html#error-#{error_code.downcase}"
        expected_message = "#{content} #{_('Error code')}: [#{error_code}](#{expected_url})"
        expect(subject.errors).to eq([expected_message])
      end
    end
  end
end
