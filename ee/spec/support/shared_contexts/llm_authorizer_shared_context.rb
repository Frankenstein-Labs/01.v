# frozen_string_literal: true

RSpec.shared_context 'with stubbed LLM authorizer' do |allowed: false|
  before do
    response = Gitlab::Llm::Utils::Authorizer::Response.new(allowed: allowed)
    allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:context).and_return(response)
  end
end
