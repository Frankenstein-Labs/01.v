# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CheckpointBlob, feature_category: :duo_agent_platform do
  let_it_be(:workflow) { create(:duo_workflows_workflow) }

  subject(:blob) { build(:duo_workflows_checkpoint_blob, workflow: workflow) }

  describe 'associations' do
    it { is_expected.to belong_to(:workflow).class_name('Ai::DuoWorkflows::Workflow') }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:namespace).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:workflow) }
    it { is_expected.to validate_presence_of(:thread_ts) }
    it { is_expected.to validate_presence_of(:channel) }
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_presence_of(:write_type) }
    it { is_expected.to validate_presence_of(:step_action) }
    it { is_expected.to validate_inclusion_of(:step_action).in_array(%w[conversation compaction]) }
    it { is_expected.to validate_presence_of(:data) }
    it { is_expected.to validate_length_of(:data).is_at_most(described_class::BLOB_DATA_LIMIT) }
  end

  describe 'syncing workflow container' do
    context 'with a project-level workflow' do
      it 'sets project_id from the workflow' do
        blob.valid?
        expect(blob.project_id).to eq(workflow.project_id)
      end
    end

    context 'with a namespace-level workflow' do
      let_it_be(:workflow) { create(:duo_workflows_workflow, namespace: create(:group)) }

      it 'sets namespace_id from the workflow' do
        blob.valid?
        expect(blob.namespace_id).to eq(workflow.namespace_id)
      end
    end
  end
end
