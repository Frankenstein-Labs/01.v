# frozen_string_literal: true

RSpec.shared_context 'for semantic search on SaaS' do
  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    allow(::Gitlab::Dedicated).to receive(:dedicated_instance?).and_return(false)
    allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
  end
end

RSpec.shared_context 'for semantic search on Dedicated' do
  before do
    stub_saas_features(gitlab_com_subscriptions: false)
    allow(::Gitlab::Dedicated).to receive(:dedicated_instance?).and_return(true)
    allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
  end
end

RSpec.shared_context 'for semantic search on Self-Managed without self-hosted AIGW' do
  before do
    stub_saas_features(gitlab_com_subscriptions: false)
    allow(::Gitlab::Dedicated).to receive(:dedicated_instance?).and_return(false)
    allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(false)
  end
end

RSpec.shared_context 'for semantic search on Self-Managed with self-hosted AIGW' do
  before do
    stub_saas_features(gitlab_com_subscriptions: false)
    allow(::Gitlab::Dedicated).to receive(:dedicated_instance?).and_return(false)
    allow(::Gitlab::AiGateway).to receive(:has_self_hosted_ai_gateway?).and_return(true)
  end
end
