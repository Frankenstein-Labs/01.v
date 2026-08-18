# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe 'gitlab_knowledge_graph_secret initializer', feature_category: :knowledge_graph do
  let(:initializer_path) { Rails.root.join('ee/config/initializers/gitlab_knowledge_graph_secret.rb') }
  let(:kg_config) { instance_double(Gitlab::Configs::Options) }

  before do
    allow(Gitlab.config).to receive(:knowledge_graph).and_return(kg_config)
    allow(Analytics::KnowledgeGraph::JwtAuth).to receive(:ensure_secret!)
  end

  context 'when knowledge_graph is enabled' do
    before do
      allow(kg_config).to receive(:[]).with('enabled').and_return(true)
    end

    it 'calls ensure_secret!' do
      load initializer_path

      expect(Analytics::KnowledgeGraph::JwtAuth).to have_received(:ensure_secret!)
    end
  end

  context 'when knowledge_graph is disabled' do
    before do
      allow(kg_config).to receive(:[]).with('enabled').and_return(false)
    end

    it 'does not call ensure_secret!' do
      load initializer_path

      expect(Analytics::KnowledgeGraph::JwtAuth).not_to have_received(:ensure_secret!)
    end
  end

  context 'when knowledge_graph enabled is not configured' do
    before do
      allow(kg_config).to receive(:[]).with('enabled').and_return(nil)
    end

    it 'does not call ensure_secret!' do
      load initializer_path

      expect(Analytics::KnowledgeGraph::JwtAuth).not_to have_received(:ensure_secret!)
    end
  end
end
