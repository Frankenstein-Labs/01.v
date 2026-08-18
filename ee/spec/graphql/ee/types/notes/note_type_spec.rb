# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Note'], feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it { expect(described_class).to have_graphql_field(:duo_workflow_links) }
  it { expect(described_class).to have_graphql_field(:duo_triggered_session) }

  describe '#duo_triggered_session', :request_store do
    let_it_be(:project) { create(:project) }
    let_it_be(:note) { create(:note, project: project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }

    before_all do
      ::Ai::DuoWorkflows::WorkflowNote.ensure_link(
        workflow: workflow, artifact: note, link_type: :triggered
      )
    end

    it 'returns the workflow when the user can read it' do
      user = create(:user, developer_of: project)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, workflow).and_return(true)

      result = batch_sync { resolve_field(:duo_triggered_session, note, current_user: user) }

      expect(result).to eq(workflow)
    end

    it 'returns nil when the user cannot read the workflow' do
      user = create(:user, guest_of: project)
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :read_duo_workflow, workflow).and_return(false)

      result = batch_sync { resolve_field(:duo_triggered_session, note, current_user: user) }

      expect(result).to be_nil
    end

    it 'does not fall back to an older authorized workflow when the newest is unauthorized' do
      user = create(:user, developer_of: project)
      newer_workflow = create(:duo_workflows_workflow, project: project)
      create(:duo_workflows_workflow_note, workflow: newer_workflow, note: note, link_type: :triggered)

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?)
        .with(user, :read_duo_workflow, newer_workflow).and_return(false)
      allow(Ability).to receive(:allowed?)
        .with(user, :read_duo_workflow, workflow).and_return(true)

      result = batch_sync { resolve_field(:duo_triggered_session, note, current_user: user) }

      expect(result).to be_nil
    end

    it 'returns nil when no triggered workflow link exists' do
      user = create(:user, developer_of: project)
      note_without_link = create(:note, project: project)

      result = batch_sync { resolve_field(:duo_triggered_session, note_without_link, current_user: user) }

      expect(result).to be_nil
    end

    it 'returns nil for system notes' do
      user = create(:user, developer_of: project)
      system_note = create(:note, :system, project: project)

      result = batch_sync { resolve_field(:duo_triggered_session, system_note, current_user: user) }

      expect(result).to be_nil
    end
  end
end
