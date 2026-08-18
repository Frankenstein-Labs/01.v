# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Ai::DuoWorkflows::BasicCheckpoint, feature_category: :duo_agent_platform do
  # Reloadable, not frozen: Checkpoint's after_save touches the workflow.
  let_it_be_with_reload(:workflow) { create(:duo_workflows_workflow) }

  subject(:serialized) { described_class.new(checkpoint).as_json }

  # The entity backs both the full checkpoint row and the header row that replaces
  # it (gitlab-org/gitlab#605653), so every attribute it exposes must exist on both.
  # A header presented through this entity used to raise NoMethodError on
  # checkpoint_ns.
  shared_examples 'a presentable checkpoint' do
    it 'exposes the langgraph identifiers' do
      expect(serialized).to include(
        thread_ts: 'ts-1',
        parent_ts: 'ts-0',
        checkpoint_ns: 'research_agent:0f8ba4c5'
      )
    end
  end

  context 'with a checkpoint' do
    let(:checkpoint) do
      create(:duo_workflows_checkpoint, workflow: workflow, thread_ts: 'ts-1', parent_ts: 'ts-0',
        checkpoint_ns: 'research_agent:0f8ba4c5')
    end

    it_behaves_like 'a presentable checkpoint'
  end

  context 'with a checkpoint header' do
    let(:checkpoint) do
      create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1', parent_ts: 'ts-0',
        checkpoint_ns: 'research_agent:0f8ba4c5')
    end

    it_behaves_like 'a presentable checkpoint'
  end
end
