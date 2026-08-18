# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Items::BaseAuditEventMessageService, feature_category: :workflow_catalog do
  it_behaves_like 'Ai::Catalog::AuditEventMessageService' do
    let_it_be(:item_name) { 'agent' }
    let_it_be(:event_name_prefix) { 'ai_catalog_agent' }
    let_it_be(:schema_version_constant) { 1 }
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:item) { create(:ai_catalog_agent, project: project) }

    let(:version) { item.latest_version }
    let(:params) { {} }
    let(:service) do
      Class.new(described_class) do
        def item_type
          'agent'
        end

        def expected_schema_version
          1
        end

        def create_messages
          ["Created AI #{item.human_item_type}"]
        end

        def build_change_descriptions
          ["Changed system prompt"]
        end
      end.new(event_type, item, params)
    end

    describe '#messages' do
      subject(:messages) { service.messages }

      context 'when event_type is create' do
        let(:event_type) { 'create_ai_catalog_agent' }

        it 'returns create messages' do
          expect(messages).to eq(['Created AI agent'])
        end
      end

      context 'when event_type is update' do
        let(:event_type) { 'update_ai_catalog_agent' }

        it 'returns update messages with no changes' do
          expect(messages).to eq(['Updated AI agent: Changed system prompt'])
        end
      end
    end

    describe '#format_list' do
      let(:event_type) { 'create_ai_catalog_agent' }

      it 'formats empty list as []' do
        result = service.send(:format_list, [])
        expect(result).to eq('[]')
      end

      it 'formats single item list' do
        result = service.send(:format_list, ['item1'])
        expect(result).to eq('[item1]')
      end

      it 'formats multiple items list with comma separation' do
        result = service.send(:format_list, %w[item1 item2 item3])
        expect(result).to eq('[item1, item2, item3]')
      end

      it 'formats nil as []' do
        result = service.send(:format_list, nil)
        expect(result).to eq('[]')
      end
    end

    describe 'abstract methods' do
      let(:event_type) { 'create_ai_catalog_agent' }
      let(:base_service) { described_class.new(event_type, item, params) }

      it 'raises NotImplementedError for item_type' do
        expect { base_service.send(:item_type) }.to raise_error(NotImplementedError)
      end

      it 'raises NotImplementedError for expected_schema_version' do
        expect { base_service.send(:expected_schema_version) }.to raise_error(NotImplementedError)
      end

      it 'raises NotImplementedError for create_messages' do
        expect { base_service.send(:create_messages) }.to raise_error(NotImplementedError)
      end

      it 'raises NotImplementedError for build_change_descriptions' do
        expect { base_service.send(:build_change_descriptions) }.to raise_error(NotImplementedError)
      end
    end
  end
end
