# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Prompts::CodeCompletion::AmazonQ, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  subject(:prompt) { described_class.new({}, current_user) }

  describe '#request_params' do
    it 'returns expected request params' do
      role_arn = "arn:aws:iam:111111111111:role/QDevAccess"

      stub_current_organization(current_user.organization)

      ::Ai::Setting.for_organization(current_user.organization).update!(
        amazon_q_role_arn: role_arn
      )

      request_params = {
        prompt_version: 2,
        model_provider: 'amazon_q',
        model_name: 'amazon_q',
        role_arn: ::Ai::Setting.for_organization(current_user.organization).amazon_q_role_arn
      }

      expect(prompt.request_params).to eq(request_params)
    end
  end
end
