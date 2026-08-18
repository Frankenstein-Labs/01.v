# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::NoteDuoMetadata, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:note) { create(:note, noteable: merge_request, project: project) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }

  subject(:metadata) { build(:note_duo_metadata, note: note, workflow_id: workflow.id) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:note).inverse_of(:duo_metadata) }
    it { is_expected.to belong_to(:workflow).class_name('Ai::DuoWorkflows::Workflow') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:note) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:workflow_id) }
    it { is_expected.to validate_uniqueness_of(:workflow_id).scoped_to(:note_id) }
  end
end
