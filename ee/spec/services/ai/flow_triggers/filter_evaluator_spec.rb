# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FlowTriggers::FilterEvaluator, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }

  let(:hook_scope) { :pipeline_hooks }
  let(:data) { { user: { id: 1 } } }

  subject(:evaluator) do
    described_class.new(flow_trigger: flow_trigger, hook_scope: hook_scope, data: data)
  end

  describe '#allowed?' do
    context 'when flow trigger has no filter and no precondition' do
      let(:flow_trigger) { build(:ai_flow_trigger, project: project, filter: {}) }

      it 'returns true' do
        expect(evaluator.allowed?).to be true
      end
    end

    context 'when filter is nil' do
      let(:flow_trigger) { build(:ai_flow_trigger, project: project, filter: nil) }

      it 'returns true' do
        expect(evaluator.allowed?).to be true
      end
    end

    context 'when flow trigger has a base filter' do
      let(:base_filter) do
        {
          'match' => 'all',
          'rules' => [{ 'field' => 'object_attributes.status', 'operator' => 'eq', 'value' => 'failed' }]
        }
      end

      let(:flow_trigger) do
        build(:ai_flow_trigger, project: project, filter: { 'pipeline_hooks' => base_filter })
      end

      context 'when the filter matches' do
        let(:data) { { object_attributes: { status: 'failed' } } }

        it 'returns true' do
          expect(evaluator.allowed?).to be true
        end
      end

      context 'when the filter does not match' do
        let(:data) { { object_attributes: { status: 'success' } } }

        it 'returns false' do
          expect(evaluator.allowed?).to be false
        end
      end
    end

    context 'when foundational flow has a precondition' do
      let_it_be(:item) { create(:ai_catalog_flow, :public, foundational_flow_reference: 'fix_pipeline/v1') }
      let_it_be(:item_consumer) { create(:ai_catalog_item_consumer, project: project, item: item) }

      let(:flow_trigger) do
        build(:ai_flow_trigger,
          project: project,
          config_path: nil,
          ai_catalog_item_consumer: item_consumer,
          event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]])
      end

      context 'when the precondition is met' do
        let(:data) { { object_attributes: { status: 'failed' } } }

        it 'returns true' do
          expect(evaluator.allowed?).to be true
        end
      end

      context 'when the precondition is not met' do
        let(:data) { { object_attributes: { status: 'success' } } }

        it 'returns false' do
          expect(evaluator.allowed?).to be false
        end
      end

      context 'when there is also a base filter' do
        let(:flow_trigger) do
          build(:ai_flow_trigger,
            project: project,
            config_path: nil,
            ai_catalog_item_consumer: item_consumer,
            event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]],
            filter: {
              'pipeline_hooks' => {
                'match' => 'all',
                'rules' => [
                  { 'field' => 'object_attributes.source', 'operator' => 'eq', 'value' => 'push' }
                ]
              }
            })
        end

        context 'when both precondition and base filter match' do
          let(:data) { { object_attributes: { status: 'failed', source: 'push' } } }

          it 'returns true' do
            expect(evaluator.allowed?).to be true
          end
        end

        context 'when precondition matches but base filter does not' do
          let(:data) { { object_attributes: { status: 'failed', source: 'web' } } }

          it 'returns false' do
            expect(evaluator.allowed?).to be false
          end
        end

        context 'when base filter matches but precondition does not' do
          let(:data) { { object_attributes: { status: 'success', source: 'push' } } }

          it 'returns false' do
            expect(evaluator.allowed?).to be false
          end
        end
      end
    end
  end
end
