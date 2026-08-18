# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::EpicsService, feature_category: :portfolio_management do
  let_it_be(:group)   { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:author)  { create(:user) }

  let(:noteable)      { create(:issue, project: project) }
  let(:issue)         { noteable }
  let(:epic)          { create(:epic, group: group) }

  describe '#change_epic_date_note' do
    let(:timestamp) { Time.current }

    context 'when start date was changed' do
      let(:noteable) { create(:epic) }

      subject { described_class.new(noteable: noteable, author: author).change_epic_date_note('start date', timestamp) }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { 'epic_date_changed' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq "changed start date to #{timestamp.strftime('%b %-d, %Y')}"
      end
    end

    context 'when start date was removed' do
      let(:noteable) { create(:epic, start_date: timestamp) }

      subject { described_class.new(noteable: noteable, author: author).change_epic_date_note('start date', nil) }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { 'epic_date_changed' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq 'removed the start date'
      end
    end
  end

  describe '#issue_promoted' do
    context 'note on the epic' do
      subject { described_class.new(noteable: epic, author: author).issue_promoted(issue, direction: :from) }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { 'moved' }
        let(:expected_noteable) { epic }
      end

      it 'sets the note text' do
        expect(subject.note).to eq("promoted from issue #{issue.to_reference(group)}")
      end
    end

    context 'note on the epic when it is a work item' do
      let_it_be(:work_item) { create(:work_item, :issue, project: project) }

      subject { described_class.new(noteable: epic, author: author).issue_promoted(work_item, direction: :from) }

      it_behaves_like 'a system note', exclude_project: true do
        let(:action) { 'moved' }
        let(:expected_noteable) { epic }
      end

      it 'sets the note text' do
        expect(subject.note).to eq("promoted from issue #{work_item.to_reference(group)}")
      end
    end

    context 'note on the issue' do
      subject { described_class.new(noteable: issue, author: author).issue_promoted(epic, direction: :to) }

      it_behaves_like 'a system note' do
        let(:action) { 'moved' }
      end

      it 'sets the note text' do
        expect(subject.note).to eq("promoted to epic #{epic.to_reference(project)}")
      end
    end
  end
end
