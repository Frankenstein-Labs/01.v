# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Templates::SummarizeNewMergeRequest, feature_category: :duo_code_review do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.owner }

  let(:source_project) { project }
  let(:source_branch) { 'feature' }
  let(:target_branch) { 'master' }

  describe '#to_prompt' do
    let(:params) do
      {
        source_project_id: source_project.id,
        source_branch: source_branch,
        target_branch: target_branch
      }
    end

    subject(:template) { described_class.new(user, project, params) }

    shared_examples_for 'prompt without errors' do
      it "returns a prompt with diff" do
        expect(template.to_prompt)
          .to include("+class Feature\n+  def foo\n+    puts 'bar'\n+  end\n+end")
      end
    end

    it_behaves_like "prompt without errors"

    it 'is under the character limit' do
      expect(template.to_prompt.size).to be <= described_class::CHARACTER_LIMIT
    end

    context 'when user cannot create merge request from source_project_id' do
      let_it_be(:source_project) { create(:project) }

      it_behaves_like "prompt without errors"
    end

    context 'when no source_project_id is specified' do
      let(:params) do
        {
          source_project_id: nil,
          source_branch: source_branch,
          target_branch: target_branch
        }
      end

      it_behaves_like "prompt without errors"
    end
  end

  describe '#extracted_diff' do
    let(:params) do
      {
        source_project_id: source_project.id,
        source_project: source_project,
        target_project: source_project,
        source_branch: source_branch,
        target_branch: target_branch,
        character_limit: described_class::CHARACTER_LIMIT
      }
    end

    subject(:template) { described_class.new(user, project, params) }

    it 'returns a diff from merge request tool' do
      expect(Gitlab::Llm::Utils::MergeRequestTool).to receive(:extract_diff)
        .with(
          source_project: params[:source_project],
          source_branch: params[:source_branch],
          target_project: params[:target_project],
          target_branch: params[:target_branch],
          character_limit: params[:character_limit]
        )
        .and_return("diff")

      expect(template.send(:extracted_diff)).to eq("diff")
    end
  end
end
