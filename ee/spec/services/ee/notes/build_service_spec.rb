# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::BuildService, feature_category: :duo_agent_platform do
  let_it_be(:project) { build_stubbed(:project) }
  let_it_be(:issue) { build_stubbed(:issue, project:) }
  let_it_be(:user) { build_stubbed(:user, developer_of: project) }

  let(:params) { { note: 'Test', noteable: issue } }

  subject(:new_note) { described_class.new(project, user, params).execute }

  describe '#execute' do
    context 'when workflow_id is provided' do
      let(:workflow) { build_stubbed(:duo_workflows_workflow, project: project, user: user) }
      let(:params) { { note: 'Test', noteable: issue, workflow_id: workflow.id } }

      it 'builds duo_metadata on the note using the project namespace_id' do
        expect(new_note.duo_metadata.workflow_id).to eq(workflow.id)
        expect(new_note.duo_metadata.namespace_id).to eq(project.namespace_id)
      end

      context 'when project does not have a namespace_id' do
        before do
          allow(project).to receive(:namespace_id).and_return(nil)
        end

        it 'does not build duo_metadata on the note' do
          expect(new_note.duo_metadata).to be_nil
        end
      end
    end

    context 'when workflow_id is absent' do
      it 'does not build duo_metadata on the note' do
        expect(new_note.duo_metadata).to be_nil
      end
    end

    context 'when workflow_id is blank' do
      let(:params) { { note: 'Test', noteable: issue, workflow_id: '' } }

      it 'does not build duo_metadata on the note' do
        expect(new_note.duo_metadata).to be_nil
      end
    end

    context 'when workflow_id is nil' do
      let(:params) { { note: 'Test', noteable: issue, workflow_id: nil } }

      it 'does not build duo_metadata on the note' do
        expect(new_note.duo_metadata).to be_nil
      end
    end
  end
end
