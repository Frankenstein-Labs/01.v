# frozen_string_literal: true

#
# Shared examples for executors that use ai gateway agent prompts
#
# Expects:
#
# - tool
# - ai_request_double
# - prompt_class
# - unit_primitive
RSpec.shared_examples 'uses ai gateway agent prompt' do
  let(:inputs) { tool.send(:prompt_options) }
  let(:prompt_version) { '^1.0.0' }
  let(:default_unit_primitive) { nil }

  before do
    allow(tool).to receive(:provider_prompt_class).and_return(prompt_class)

    allow(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).with(user, {
      unit_primitive_name: unit_primitive.to_sym,
      tracking_context: { request_id: nil, action: unit_primitive }
    }).and_return(ai_request_double)
  end

  it 'executes a request with correct params' do
    prompt = tool.prompt
    prompt[:options] ||= {}
    prompt[:options].merge!({
      use_ai_gateway_agent_prompt: true,
      inputs: inputs,
      prompt_version: prompt_version
    })

    expect(ai_request_double).to receive(:request).with(prompt, unit_primitive: unit_primitive)

    tool.execute
  end

  context 'when the feature flag is disabled' do
    before do
      stub_feature_flags("prompt_migration_#{unit_primitive}": false)
    end

    it 'executes a request with correct params' do
      expect(ai_request_double).to receive(:request).with(
        tool.prompt,
        unit_primitive: default_unit_primitive
      )

      tool.execute
    end
  end
end
