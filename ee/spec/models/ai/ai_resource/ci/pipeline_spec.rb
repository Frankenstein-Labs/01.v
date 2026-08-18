# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Ci::Pipeline, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch', source: :push) }

  subject(:ai_resource) { described_class.new(user, pipeline) }

  describe '#serialize_for_ai' do
    let(:result) { ai_resource.serialize_for_ai }

    it 'returns pipeline attributes', :aggregate_failures do
      expect(result[:id]).to eq(pipeline.id)
      expect(result[:iid]).to eq(pipeline.iid)
      expect(result[:ref]).to eq('feature-branch')
      expect(result[:sha]).to eq(pipeline.sha)
      expect(result[:source]).to eq('push')
      expect(result[:status]).to eq(pipeline.status)
      expect(result[:project_full_path]).to eq(project.full_path)
      expect(result[:web_url]).to include("/pipelines/#{pipeline.id}")
      expect(result[:source_ref]).to eq('feature-branch')
      expect(result[:created_at]).to be_present
    end

    context 'when pipeline has no project' do
      before do
        allow(resource).to receive(:project).and_return(nil)
      end

      let(:resource) { pipeline }
      let(:ai_resource_instance) { described_class.new(user, resource) }
      let(:result) { ai_resource_instance.serialize_for_ai }

      it 'returns nil for project-dependent fields', :aggregate_failures do
        expect(result[:project_full_path]).to be_nil
        expect(result[:web_url]).to be_nil
        expect(result[:id]).to eq(pipeline.id)
      end
    end
  end

  describe '#current_page_type' do
    it 'returns pipeline' do
      expect(ai_resource.current_page_type).to eq('pipeline')
    end
  end

  describe '#current_page_params' do
    it 'returns hash with type' do
      expect(ai_resource.current_page_params).to eq({ type: 'pipeline' })
    end
  end
end
