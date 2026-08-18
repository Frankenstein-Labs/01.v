# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BoardLabel do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:board) }
    it { is_expected.to validate_presence_of(:label) }

    describe 'group presence' do
      it { is_expected.to validate_presence_of(:group) }

      context 'when project is present' do
        subject { described_class.new(project: build_stubbed(:project)) }

        it { is_expected.not_to validate_presence_of(:group) }
      end
    end

    describe 'project presence' do
      it { is_expected.to validate_presence_of(:project) }

      context 'when group is present' do
        subject { described_class.new(group: build_stubbed(:group)) }

        it { is_expected.not_to validate_presence_of(:project) }
      end
    end

    describe 'group and project mutually exclusive' do
      context 'when project is present' do
        it 'validates that project and group are mutually exclusive' do
          expect(described_class.new(project: build_stubbed(:project))).to validate_absence_of(:group)
            .with_message(_("can't be specified if a project was already provided"))
        end
      end

      context 'when project is not present' do
        it { is_expected.not_to validate_absence_of(:group) }
      end
    end
  end

  describe 'ensure_group_or_project' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:label) { create(:label, project: project) }

    context 'when board belongs to a group' do
      let_it_be(:board) { create(:board, group: group) }

      it 'sets group_id from the parent board' do
        board_label = described_class.create!(board: board, label: label)

        expect(board_label.group_id).to eq(board.group_id)
      end
    end

    context 'when board belongs to a project' do
      let_it_be(:board) { create(:board, project: project) }

      it 'sets project_id from the parent board' do
        board_label = described_class.create!(board: board, label: label)

        expect(board_label.project_id).to eq(board.project_id)
      end
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:label) }
  end
end
