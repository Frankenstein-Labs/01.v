# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Tracking::EventPropertiesBuilder, feature_category: :workflow_catalog do
  subject(:to_h) { described_class.new(item: item, version: version).to_h }

  describe '#initialize' do
    let_it_be(:item) { create(:ai_catalog_item, :agent) }

    it 'raises ArgumentError when item is nil' do
      expect { described_class.new(item: nil, version: item.latest_version) }
        .to raise_error(ArgumentError, 'item is required')
    end

    it 'raises ArgumentError when version is nil' do
      expect { described_class.new(item: item, version: nil) }
        .to raise_error(ArgumentError, 'version is required')
    end
  end

  describe '#to_h' do
    context 'with a custom agent' do
      let_it_be(:item) { create(:ai_catalog_item, :agent) }
      let(:version) { item.latest_version }

      it 'returns the expected properties' do
        expect(to_h).to eq(
          item_type: 'custom_agent',
          item_version: item.latest_version.version,
          item_schema_version: 'v1',
          custom_item_id: item.id,
          tools: 'gitlab_blob_search'
        )
      end

      describe 'item_schema_version' do
        include Ai::Catalog::TestHelpers

        let_it_be(:organization) { create(:common_organization) }
        let_it_be(:project) { create(:project, organization: organization) }
        let_it_be(:item) { create(:ai_catalog_agent, organization: organization, project: project) }
        let_it_be(:user) { project.owner }

        before do
          enable_ai_catalog
        end

        # A custom agent is wrapped as a flow when sent to Duo Workflow Service. The
        # hardcoded item_schema_version for custom agents must therefore stay in sync
        # with the `version` emitted in that wrapped flow config. This guards against
        # the hardcoded value drifting if the wrapping changes (for example, a future
        # V2 wrapper).
        it 'matches the version of the flow config the agent is wrapped as' do
          flow_config_yaml = ::Ai::Catalog::Agents::BuildFlowConfigService.new(
            project: project,
            current_user: user,
            params: { agent_version: item.latest_version, flow_config_type: 'chat' }
          ).execute.payload[:flow_config]

          flow_config_version = YAML.safe_load(flow_config_yaml)['version']

          expect(to_h[:item_schema_version]).to eq(flow_config_version)
        end
      end

      context 'with mcp_tools and mcp_servers in the definition' do
        let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, name: 'my_server') }
        let_it_be(:other_mcp_server) { create(:ai_catalog_mcp_server, name: 'other_server') }
        let_it_be(:item) do
          create(:ai_catalog_item, :agent).tap do |i|
            i.latest_version.update!(
              definition: {
                'system_prompt' => 'Prompt',
                'tools' => [1],
                'mcp_tools' => %w[search create_issue],
                'mcp_servers' => [mcp_server.id, other_mcp_server.id]
              }
            )
          end
        end

        it 'returns the expected properties with mcp_tools as names and mcp_servers as IDs' do
          expect(to_h).to eq(
            item_type: 'custom_agent',
            item_version: item.latest_version.version,
            item_schema_version: 'v1',
            custom_item_id: item.id,
            tools: 'gitlab_blob_search',
            mcp_tools: 'search,create_issue',
            mcp_servers: "#{mcp_server.id},#{other_mcp_server.id}"
          )
        end
      end

      context 'with no tools in the definition' do
        let_it_be(:item) do
          create(:ai_catalog_item, :agent).tap do |i|
            i.latest_version.update!(
              definition: { 'system_prompt' => 'Prompt', 'tools' => [] }
            )
          end
        end

        it 'returns the expected properties without the tools key' do
          expect(to_h).to eq(
            item_type: 'custom_agent',
            item_version: item.latest_version.version,
            item_schema_version: 'v1',
            custom_item_id: item.id
          )
        end
      end
    end

    context 'with a custom flow' do
      let_it_be(:item, reload: true) { create(:ai_catalog_item, :flow) }
      let(:version_with_components) do
        create(:ai_catalog_flow_version, item: item, definition: {
          'version' => 'v1',
          'environment' => 'ambient',
          'components' => [
            { 'name' => 'planner', 'type' => 'AgentComponent', 'prompt_id' => 'p1',
              'toolset' => ['read_file', { 'create_merge_request_note' => { 'internal' => true } }] },
            { 'name' => 'tool_runner', 'type' => 'DeterministicStepComponent',
              'tool_name' => 'edit_file' },
            { 'name' => 'executor', 'type' => 'AgentComponent', 'prompt_id' => 'p2',
              'toolset' => %w[read_file grep] }
          ],
          'routers' => [],
          'flow' => { 'entry_point' => 'planner' },
          'yaml_definition' => 'placeholder'
        })
      end

      let(:version) { version_with_components }

      it 'returns the expected properties' do
        expect(to_h).to eq(
          item_type: 'custom_flow',
          item_version: version_with_components.version,
          item_schema_version: 'v1',
          custom_item_id: item.id,
          tools: 'read_file,create_merge_request_note,edit_file,read_file,grep',
          components: 'AgentComponent,DeterministicStepComponent,AgentComponent'
        )
      end
    end

    context 'with a custom external agent (third_party_flow, non-foundational)' do
      let_it_be(:item) { create(:ai_catalog_item, :third_party_flow) }
      let(:version) { item.latest_version }

      it 'returns the expected properties' do
        expect(to_h).to eq(
          item_type: 'custom_external_agent',
          item_version: item.latest_version.version,
          custom_item_id: item.id
        )
      end
    end

    context 'with a foundational flow' do
      let_it_be(:item) do
        create(:ai_catalog_item, :flow, :public,
          foundational_flow_reference: 'developer/v1',
          verification_level: :gitlab_maintained)
      end

      let(:version) { item.latest_version }

      it 'returns the expected properties' do
        expect(to_h).to eq(
          item_type: 'foundational_flow',
          item_version: '^2.0.0',
          item_schema_version: 'v1',
          flow_name: 'developer'
        )
      end
    end

    context 'with a foundational external agent (third_party_flow + foundational)' do
      let_it_be(:item) do
        create(:ai_catalog_item, :third_party_flow, :public,
          verification_level: :gitlab_maintained)
      end

      let(:version) { item.latest_version }

      it 'returns the expected properties' do
        expect(to_h).to eq(
          item_type: 'foundational_external_agent',
          item_version: item.latest_version.version,
          custom_item_id: item.id
        )
      end
    end

    context 'when an explicit version is passed' do
      let_it_be(:item, reload: true) { create(:ai_catalog_item, :agent) }
      let(:other_version) do
        create(:ai_catalog_agent_version, item: item, version: '9.9.9')
      end

      let(:version) { other_version }

      it 'uses the passed version for item_version' do
        expect(to_h[:item_version]).to eq('9.9.9')
      end
    end

    context 'when item does not match any handled type' do
      let(:item) { create(:ai_catalog_item, :agent) }
      let(:version) { item.latest_version }

      before do
        # Simulate an item that doesn't match any of the find_item_type branches
        # (e.g. a future item_type enum value or a removed predicate).
        allow(item).to receive_messages(
          foundational_flow?: false,
          foundational_third_party_flow?: false,
          custom_flow?: false,
          custom_third_party_flow?: false,
          custom_agent?: false
        )
      end

      context 'in dev/test mode' do
        it 'raises UnhandledItemType' do
          expect { to_h }.to raise_error(described_class::UnhandledItemType)
        end
      end

      context 'in production mode' do
        before do
          allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(false)
        end

        it 'logs to Sentry and returns an empty hash' do
          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
            .with(
              an_instance_of(described_class::UnhandledItemType),
              hash_including(item_id: item.id, item_type: item.item_type)
            ).and_call_original

          expect(to_h).to eq({})
        end
      end
    end

    context 'when an unexpected error occurs during hash construction' do
      let_it_be(:item) { create(:ai_catalog_item, :agent) }
      let(:version) { item.latest_version }
      let(:error) { RuntimeError.new('error') }

      before do
        # Force an error during one of the property method calls.
        allow(Ai::Catalog::BuiltInTool).to receive(:where).and_raise(error)
      end

      context 'in dev/test mode' do
        it 'tracks the exception and re-raises' do
          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
            .with(
              error,
              hash_including(
                item_id: item.id,
                item_version_id: item.latest_version.id,
                item_type: 'custom_agent'
              )
            ).and_call_original

          expect { to_h }.to raise_error(RuntimeError, 'error')
        end
      end

      context 'in production mode' do
        before do
          allow(Gitlab::ErrorTracking).to receive(:should_raise_for_dev?).and_return(false)
        end

        it 'logs to Sentry and returns an empty hash' do
          expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
            .with(
              error,
              hash_including(
                item_id: item.id,
                item_version_id: item.latest_version.id,
                item_type: 'custom_agent'
              )
            ).and_call_original

          expect(to_h).to eq({})
        end
      end
    end
  end
end
