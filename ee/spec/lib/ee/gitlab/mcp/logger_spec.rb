# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Mcp::Logger, feature_category: :mcp_server do
  describe '#conditional_info' do
    let_it_be(:user) { create(:user) }
    let(:logger) { described_class.build }

    let(:base_payload) do
      {
        message: 'test',
        event_name: 'tool_call',
        ai_component: 'mcp_server',
        tool_name: 'search',
        Labkit::Fields::GL_USER_ID => user.id
      }
    end

    let(:expanded_payload) { base_payload.merge(arguments: { search: 'secret' }) }

    def log(namespace: nil)
      logger.conditional_info(user,
        message: 'test',
        event_name: 'tool_call',
        ai_component: 'mcp_server',
        namespace: namespace,
        tool_name: 'search',
        expanded: { arguments: { search: 'secret' } })
    end

    before do
      stub_feature_flags(expanded_ai_logging: false)
      allow(::Gitlab::CurrentSettings).to receive(:enabled_expanded_logging).and_return(false)
    end

    context 'when the instance expanded logging setting is enabled' do
      before do
        allow(::Gitlab::CurrentSettings).to receive(:enabled_expanded_logging).and_return(true)
      end

      it 'logs the expanded payload' do
        expect(logger).to receive(:info).with(expanded_payload)

        log
      end
    end

    context 'when the feature flag is enabled for the user' do
      before do
        stub_feature_flags(expanded_ai_logging: user)
      end

      it 'logs the expanded payload' do
        expect(logger).to receive(:info).with(expanded_payload)

        log
      end
    end

    context 'when the namespace opts in to AI data collection' do
      let_it_be(:namespace) { create(:group, ai_usage_data_collection_enabled: true) }

      it 'logs the expanded payload' do
        expect(logger).to receive(:info).with(expanded_payload)

        log(namespace: namespace)
      end
    end

    context 'when no setting permits expanded logging' do
      let_it_be(:namespace) { create(:group, ai_usage_data_collection_enabled: false) }

      it 'drops the expanded payload' do
        expect(logger).to receive(:info).with(base_payload)

        log(namespace: namespace)
      end
    end
  end
end
