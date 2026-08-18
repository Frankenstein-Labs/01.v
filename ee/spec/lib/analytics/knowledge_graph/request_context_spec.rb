# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Analytics::KnowledgeGraph::RequestContext, feature_category: :knowledge_graph do
  describe '#initialize' do
    it 'defaults all attributes to nil' do
      context = described_class.new

      expect(context.source_type).to be_nil
      expect(context.session_id).to be_nil
      expect(context.user_agent).to be_nil
    end

    it 'accepts source_type, session_id, and user_agent' do
      context = described_class.new(source_type: 'rest', session_id: 'workflow-123', user_agent: 'TestAgent/1.0')

      expect(context.source_type).to eq('rest')
      expect(context.session_id).to eq('workflow-123')
      expect(context.user_agent).to eq('TestAgent/1.0')
    end
  end
end
