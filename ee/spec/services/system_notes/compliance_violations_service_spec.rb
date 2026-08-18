# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::ComplianceViolationsService, feature_category: :compliance_management do
  let_it_be(:group) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: group) }
  let_it_be(:author) { create(:user) }
  let_it_be_with_reload(:compliance_violation) do
    create(:project_compliance_violation, namespace: group, project: project)
  end

  let(:service) { described_class.new(noteable: compliance_violation, container: project, author: author) }

  describe '#change_violation_status' do
    subject(:create_note) { service.change_violation_status }

    where(:status, :humanized_status) do
      [
        ['detected', 'Detected'],
        ['in_review', 'In review'],
        ['resolved', 'Resolved'],
        ['dismissed', 'Dismissed']
      ]
    end

    with_them do
      before do
        compliance_violation.update!(status: status)
      end

      it 'creates a system note with the correct attributes' do
        expect { create_note }.to change { Note.count }.by(1)

        created_note = Note.last
        expect(created_note.noteable).to eq(compliance_violation)
        expect(created_note.project).to eq(project)
        expect(created_note.author).to eq(author)
        expect(created_note.note).to eq("changed status to #{humanized_status}")
        expect(created_note.system).to be_truthy
      end
    end
  end

  describe '#link_issue' do
    let_it_be_with_reload(:issue) { create(:issue, project: project) }
    let_it_be_with_reload(:cross_project_issue) { create(:issue) }

    subject(:create_note) { service.link_issue(issue) }

    context 'when linking an issue from the same project' do
      it 'creates a system note with the correct attributes' do
        expect { create_note }.to change { Note.count }.by(1)

        created_note = Note.last
        expected_note = "marked this compliance violation as related to #{issue.to_reference(full: true)}"
        expect(created_note.noteable).to eq(compliance_violation)
        expect(created_note.project).to eq(project)
        expect(created_note.author).to eq(author)
        expect(created_note.note).to eq(expected_note)
        expect(created_note.system).to be_truthy
        expect(created_note.system_note_metadata.action).to eq('relate')
      end
    end

    context 'when linking an issue from a different project' do
      subject(:create_note) { service.link_issue(cross_project_issue) }

      it 'creates a system note with full reference' do
        expect { create_note }.to change { Note.count }.by(1)

        created_note = Note.last
        expected_note = "marked this compliance violation as related to #{cross_project_issue.to_reference(full: true)}"
        expect(created_note.note).to eq(expected_note)
        expect(created_note.system_note_metadata.action).to eq('relate')
      end
    end
  end

  describe '#unlink_issue' do
    let_it_be_with_reload(:issue) { create(:issue, project: project) }
    let_it_be_with_reload(:cross_project_issue) { create(:issue) }

    subject(:create_note) { service.unlink_issue(issue) }

    context 'when unlinking an issue from the same project' do
      it 'creates a system note with the correct attributes' do
        expect { create_note }.to change { Note.count }.by(1)

        created_note = Note.last
        expect(created_note.noteable).to eq(compliance_violation)
        expect(created_note.project).to eq(project)
        expect(created_note.author).to eq(author)
        expect(created_note.note).to eq("removed the relation with #{issue.to_reference(full: true)}")
        expect(created_note.system).to be_truthy
        expect(created_note.system_note_metadata.action).to eq('unrelate')
      end
    end

    context 'when unlinking an issue from a different project' do
      subject(:create_note) { service.unlink_issue(cross_project_issue) }

      it 'creates a system note with full reference' do
        expect { create_note }.to change { Note.count }.by(1)

        created_note = Note.last
        expect(created_note.note).to eq("removed the relation with #{cross_project_issue.to_reference(full: true)}")
        expect(created_note.system_note_metadata.action).to eq('unrelate')
      end
    end
  end
end
