# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Tools::SlashCommandTool, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  let(:ai_request_double) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }
  let_it_be_with_reload(:group) { create(:group) }
  let(:resource) { group }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      current_user: user, container: nil, resource: resource, ai_request: ai_request_double
    )
  end

  subject(:tool) do
    Class.new(described_class) do
      def authorize
        true
      end
    end.new(context: context, options: {})
  end

  it 'raises not implemented error without ai_request implemented' do
    expect { tool.execute }.to raise_error(NotImplementedError)
  end

  it 'raises not implemented error without allow_blank_message implemented' do
    expect { tool.send(:allow_blank_message?) }.to raise_error(NotImplementedError)
  end
end
