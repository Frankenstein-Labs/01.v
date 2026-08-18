# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ThirdPartyFlows::AuditEventMessageService, feature_category: :workflow_catalog do
  it_behaves_like 'Ai::Catalog::AuditEventMessageService' do
    let_it_be(:item_name, freeze: false) { 'external agent' }
    let_it_be(:event_name_prefix, freeze: false) { 'ai_catalog_third_party_flow' }
    let_it_be(:schema_version_constant, freeze: false) { Ai::Catalog::ItemVersion::THIRD_PARTY_FLOW_SCHEMA_VERSION }
    let_it_be(:project, freeze: false) { create(:project) }
    let_it_be_with_reload(:item) { create(:ai_catalog_third_party_flow, project: project) }

    let(:version) { item.latest_version }
    let(:params) { {} }
    let(:service) { described_class.new(event_type, item, params) }

    describe '#messages' do
      subject(:messages) { service.messages }

      context 'when event_type is create_ai_catalog_third_party_flow' do
        let(:event_type) { 'create_ai_catalog_third_party_flow' }

        let(:create_definition) do
          {
            'image' => 'node:22',
            'commands' => ['npm install', 'npm start'],
            'injectGatewayToken' => true
          }
        end

        before do
          version.update!(definition: create_definition)
        end

        context 'when third_party_flow is private' do
          it 'returns create messages for private external agent' do
            expect(messages).to contain_exactly(
              "Created a new private AI external agent",
              "Created new draft version #{version.version} of AI external agent"
            )
          end
        end

        context 'when third_party_flow is public' do
          before do
            item.update!(visibility: :public)
          end

          it 'returns create messages for public external agent' do
            expect(messages).to contain_exactly(
              "Created a new public AI external agent",
              "Created new draft version #{version.version} of AI external agent"
            )
          end
        end

        context 'when third_party_flow is restricted' do
          before do
            item.update!(visibility: :restricted)
          end

          it 'returns create messages for restricted external agent' do
            expect(messages).to contain_exactly(
              "Created a new restricted AI external agent",
              "Created new draft version #{version.version} of AI external agent"
            )
          end
        end

        context 'when version is released' do
          before do
            version.update!(release_date: Time.current)
          end

          it 'returns create messages with released version' do
            expect(messages).to contain_exactly(
              "Created a new private AI external agent",
              "Released version #{version.version} of AI external agent"
            )
          end
        end
      end

      context 'when event_type is update_ai_catalog_third_party_flow' do
        let(:event_type) { 'update_ai_catalog_third_party_flow' }

        let(:old_definition) do
          {
            'image' => 'node:20',
            'commands' => ['npm install', 'npm start'],
            'injectGatewayToken' => true
          }
        end

        let(:new_definition) do
          {
            'image' => 'node:20',
            'commands' => ['npm install', 'npm start'],
            'injectGatewayToken' => true
          }
        end

        let(:params) { { old_definition: old_definition } }

        before do
          version.update!(definition: new_definition)
        end

        context 'when image changes' do
          let(:new_definition) do
            {
              'image' => 'node:22',
              'commands' => ['npm install', 'npm start'],
              'injectGatewayToken' => true
            }
          end

          it 'returns image change message' do
            expect(messages).to contain_exactly(
              "Updated AI external agent: Changed image"
            )
          end
        end

        context 'when commands change' do
          let(:new_definition) do
            {
              'image' => 'node:20',
              'commands' => ['npm install', 'npm test', 'npm start'],
              'injectGatewayToken' => true
            }
          end

          it 'returns commands change message' do
            expect(messages).to contain_exactly(
              "Updated AI external agent: Changed commands"
            )
          end
        end

        context 'when variables change' do
          let(:old_definition) do
            {
              'image' => 'node:20',
              'commands' => ['npm install', 'npm start'],
              'injectGatewayToken' => true,
              'variables' => %w[VAR1 VAR2]
            }
          end

          let(:new_definition) do
            {
              'image' => 'node:20',
              'commands' => ['npm install', 'npm start'],
              'injectGatewayToken' => true,
              'variables' => %w[VAR1 VAR3]
            }
          end

          it 'returns variables change message' do
            expect(messages).to contain_exactly(
              "Updated AI external agent: Changed variables"
            )
          end
        end

        context 'when both image and commands change' do
          let(:new_definition) do
            {
              'image' => 'node:22',
              'commands' => ['npm ci', 'npm start'],
              'injectGatewayToken' => true
            }
          end

          it 'returns both change messages' do
            expect(messages).to contain_exactly(
              "Updated AI external agent: Changed image, Changed commands"
            )
          end
        end

        context 'when image, commands, and variables all change' do
          let(:old_definition) do
            {
              'image' => 'node:20',
              'commands' => ['npm install', 'npm start'],
              'injectGatewayToken' => false,
              'variables' => ['VAR1']
            }
          end

          let(:new_definition) do
            {
              'image' => 'node:22',
              'commands' => ['npm ci', 'npm start'],
              'injectGatewayToken' => true,
              'variables' => %w[VAR1 VAR2]
            }
          end

          it 'returns all change messages' do
            expect(messages).to contain_exactly(
              "Updated AI external agent: Changed image, Changed commands, " \
                "Changed variables, Enabled AI Gateway token injection"
            )
          end
        end

        context 'when visibility changes to public' do
          before do
            item.update!(visibility: :public)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI external agent public')
          end
        end

        context 'when visibility changes to restricted' do
          before do
            item.update!(visibility: :restricted)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI external agent restricted')
          end
        end

        context 'when visibility changes to private' do
          let_it_be(:item, freeze: false) do
            create(:ai_catalog_third_party_flow, :public, project: project)
          end

          before do
            item.update!(visibility: :private)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI external agent private')
          end
        end

        context 'when new version is created' do
          let(:new_definition) do
            {
              'image' => 'node:22',
              'commands' => ['npm install', 'npm start'],
              'injectGatewayToken' => true
            }
          end

          before do
            new_version = create(
              :ai_catalog_third_party_flow_version,
              item: item,
              version: '2.0.0',
              definition: new_definition
            )
            item.update!(latest_version: new_version)
          end

          it 'returns version creation message' do
            expect(messages).to contain_exactly(
              "Created new draft version 2.0.0 of AI external agent",
              "Updated AI external agent: Changed image"
            )
          end
        end

        context 'when version is released' do
          before do
            version.update!(release_date: Time.current)
          end

          it 'returns version release message' do
            expect(messages).to contain_exactly(
              "Released version #{version.version} of AI external agent"
            )
          end
        end

        context 'when the third_party_flow name or description updated but the version definition remains unchanged' do
          before do
            item.update!(name: "New external agent name")
          end

          it 'returns default update message' do
            expect(messages).to eq(['Updated AI external agent'])
          end
        end

        context 'when injectGatewayToken changes from true to false' do
          let(:new_definition) do
            {
              'image' => 'node:20',
              'commands' => ['npm install', 'npm start'],
              'injectGatewayToken' => false
            }
          end

          it 'returns disabled AI Gateway token injection message' do
            expect(messages).to contain_exactly(
              'Updated AI external agent: Disabled AI Gateway token injection'
            )
          end
        end
      end
    end
  end
end
