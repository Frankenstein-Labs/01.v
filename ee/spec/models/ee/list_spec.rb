# frozen_string_literal: true

require 'spec_helper'

RSpec.describe List do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :empty_repo, group: group) }
  let_it_be(:board) { create(:board, project: project) }

  let_it_be(:system_defined_status) { build(:work_item_system_defined_status) }

  let(:custom_status) { build(:work_item_custom_status) }

  describe 'relationships' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:milestone) }
    it { is_expected.to belong_to(:iteration) }
    it { is_expected.to belong_to(:custom_status).class_name('WorkItems::Statuses::Custom::Status').optional }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:max_issue_count).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:max_issue_weight).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_inclusion_of(:limit_metric).in_array(EE::List::LIMIT_METRIC_TYPES).allow_nil }
  end

  context 'when it is an assignee type' do
    subject { described_class.new(list_type: :assignee, board: board) }

    it { is_expected.to be_destroyable }
    it { is_expected.to be_movable }

    describe 'validations' do
      it { is_expected.to validate_presence_of(:user) }
    end

    describe '#title' do
      it 'returns the username as title' do
        subject.user = create(:user, username: 'some_user')

        expect(subject.title).to eq('@some_user')
      end
    end
  end

  context 'when it is a milestone type' do
    let(:milestone) { build(:milestone, title: 'awesome-release') }

    subject { described_class.new(list_type: :milestone, milestone: milestone, board: board) }

    it { is_expected.to be_destroyable }
    it { is_expected.to be_movable }

    describe 'validations' do
      it { is_expected.to validate_presence_of(:milestone) }

      it 'is invalid when feature is not available' do
        stub_licensed_features(board_milestone_lists: false)

        expect(subject).to be_invalid
        expect(subject.errors[:list_type])
          .to contain_exactly('Milestone lists not available with your current license')
      end
    end

    describe '#title' do
      it 'returns the milestone title' do
        expect(subject.title).to eq('awesome-release')
      end
    end
  end

  context 'when it is an iteration type' do
    let(:iteration) { build(:iteration, group: group) }

    subject { described_class.new(list_type: :iteration, iteration: iteration, board: board) }

    it { is_expected.to be_destroyable }
    it { is_expected.to be_movable }

    describe 'validations' do
      it { is_expected.to validate_presence_of(:iteration) }

      it 'is invalid when feature is not available' do
        stub_licensed_features(board_iteration_lists: false)

        expect(subject).to be_invalid
        expect(subject.errors[:list_type])
          .to contain_exactly('Iteration lists not available with your current license')
      end
    end

    describe '#title' do
      it 'returns the iteration cadence and period as title' do
        expect(subject.title).to eq(iteration.display_text)
      end
    end
  end

  context 'when it is a status type' do
    subject do
      build(:list, list_type: :status, system_defined_status: system_defined_status, board: board, position: 2)
    end

    before do
      stub_licensed_features(board_status_lists: true)

      # Reload group to clear the converted_statuses association
      group.reload
    end

    context 'with system defined status' do
      it { is_expected.to be_destroyable }
      it { is_expected.to be_movable }

      describe 'validations' do
        it { is_expected.to be_valid }

        it 'is invalid when feature is not available' do
          stub_licensed_features(board_status_lists: false)

          expect(subject).to be_invalid
          expect(subject.errors[:list_type])
            .to contain_exactly('Status lists not available with your current license')
        end
      end

      describe '#status' do
        it 'returns the system defined status' do
          expect(subject.status).to eq(system_defined_status)
        end
      end

      describe '#title' do
        it 'returns the system defined status name' do
          expect(subject.title).to eq(system_defined_status.name)
        end
      end

      context 'when namespace has converted statuses' do
        let_it_be_with_reload(:custom_status) do
          create(:work_item_custom_status, namespace: group,
            converted_from_system_defined_status_identifier: system_defined_status.id)
        end

        describe '#status' do
          it 'returns the custom status' do
            expect(subject.status).to eq(custom_status)
          end
        end

        describe '#title' do
          it 'returns the custom status name' do
            expect(subject.title).to eq(custom_status.name)
          end
        end
      end
    end

    context 'with duplicate system defined status' do
      it 'is invalid' do
        create(:list, list_type: :status, system_defined_status: system_defined_status, board: board, position: 2)

        expect(subject).to be_invalid
        expect(subject.errors[:base]).to contain_exactly('A list for this status already exists on the board')
      end
    end

    context 'with custom status' do
      subject do
        build(:list, list_type: :status, custom_status: custom_status, board: board, position: 2)
      end

      it { is_expected.to be_destroyable }
      it { is_expected.to be_movable }

      describe 'validations' do
        it { is_expected.to be_valid }

        it 'is invalid when feature is not available' do
          stub_licensed_features(board_status_lists: false)

          expect(subject).to be_invalid
          expect(subject.errors[:list_type])
            .to contain_exactly('Status lists not available with your current license')
        end
      end

      describe '#status' do
        it 'returns the custom status' do
          expect(subject.status).to eq(custom_status)
        end
      end

      describe '#title' do
        it 'returns the custom status name' do
          expect(subject.title).to eq(custom_status.name)
        end
      end
    end

    context 'with duplicate custom status' do
      subject do
        build(:list, list_type: :status, custom_status: custom_status, board: board, position: 2)
      end

      it 'is invalid' do
        create(:list, list_type: :status, custom_status: custom_status, board: board, position: 2)

        expect(subject).to be_invalid
        expect(subject.errors[:base]).to contain_exactly('A list for this status already exists on the board')
      end
    end

    context 'with system defined and custom_status' do
      subject do
        build(:list, list_type: :status, system_defined_status: system_defined_status, custom_status: custom_status,
          board: board, position: 2)
      end

      it 'is invalid' do
        expect(subject).to be_invalid
        expect(subject.errors[:base])
          .to contain_exactly('Exactly one of system_defined_status, custom_status must be present')
      end
    end

    context 'without any status' do
      subject do
        build(:list, list_type: :status, board: board, position: 2)
      end

      it 'is invalid' do
        expect(subject).to be_invalid
        expect(subject.errors[:base])
          .to contain_exactly('Exactly one of system_defined_status, custom_status must be present')
      end
    end
  end

  describe '.with_open_status_categories' do
    let_it_be(:system_defined_todo_status) { build(:work_item_system_defined_status, :to_do) }
    let_it_be(:system_defined_done_status) { build(:work_item_system_defined_status, :done) }
    let_it_be(:custom_todo_status) { create(:work_item_custom_status, :open, namespace: group) }
    let_it_be(:custom_todo_status_without_mapping) do
      create(:work_item_custom_status, :without_conversion_mapping, namespace: group)
    end

    let_it_be(:custom_done_status) { create(:work_item_custom_status, :closed, namespace: group) }
    let_it_be(:non_status_list) { create(:list, list_type: :label, board: board) }

    before do
      stub_licensed_features(board_status_lists: true, work_item_status: true)
    end

    subject { described_class.with_open_status_categories }

    context 'when status lists exist' do
      let_it_be(:open_system_defined_status_list) do
        build(:list, list_type: :status, system_defined_status: system_defined_todo_status,
          board: board, project: project).tap do |list|
          list.save!(validate: false)
        end
      end

      let_it_be(:closed_system_defined_status_list) do
        build(:list, list_type: :status, system_defined_status: system_defined_done_status, board: board,
          project: project).tap do |list|
          list.save!(validate: false)
        end
      end

      let_it_be(:open_custom_status_list) do
        build(:list, list_type: :status, custom_status: custom_todo_status, board: board,
          project: project).tap do |list|
          list.save!(validate: false)
        end
      end

      let_it_be(:open_custom_status_list_without_mapping) do
        build(:list, list_type: :status, custom_status: custom_todo_status_without_mapping, board: board,
          project: project).tap do |list|
          list.save!(validate: false)
        end
      end

      let_it_be(:closed_custom_status_list) do
        build(:list, list_type: :status, custom_status: custom_done_status, board: board,
          project: project).tap do |list|
          list.save!(validate: false)
        end
      end

      it 'returns only status lists with open categories' do
        expect(subject).to contain_exactly(open_system_defined_status_list, open_custom_status_list,
          open_custom_status_list_without_mapping)
      end
    end

    context 'when no status lists exist' do
      it 'returns empty collection' do
        expect(subject).to be_empty
      end
    end
  end

  describe '#status=' do
    let(:list) { build(:list, list_type: :status, board: board, position: 2) }

    context 'when setting a system-defined status' do
      it 'sets the system-defined status and clears custom status' do
        list.status = system_defined_status

        expect(list.system_defined_status).to eq(system_defined_status)
        expect(list.custom_status).to be_nil
      end
    end

    context 'when setting a custom status' do
      it 'sets the custom status and clears system-defined status' do
        list.status = custom_status

        expect(list.custom_status).to eq(custom_status)
        expect(list.system_defined_status).to be_nil
      end
    end

    context 'when setting nil' do
      it 'does not set any status' do
        list.status = nil

        expect(list.system_defined_status).to be_nil
        expect(list.custom_status).to be_nil
      end
    end

    context 'when list is not a status type' do
      let(:list) { build(:list, list_type: :milestone, board: board, milestone: create(:milestone)) }

      context 'when setting a system-defined status' do
        it 'does not set any status' do
          list.status = system_defined_status

          expect(list.system_defined_status).to be_nil
          expect(list.custom_status).to be_nil
        end
      end

      context 'when setting a custom status' do
        it 'does not set any status' do
          list.status = custom_status

          expect(list.system_defined_status).to be_nil
          expect(list.custom_status).to be_nil
        end
      end
    end
  end

  describe '#wip_limits_available?' do
    let!(:board1) { create(:board, resource_parent: project, name: 'b') }
    let!(:board2) { create(:board, resource_parent: group, name: 'a') }

    let!(:list1) { create(:list, board: board1) }
    let!(:list2) { create(:list, board: board2) }

    context 'with enabled wip_limits' do
      before do
        stub_licensed_features(wip_limits: true)
      end

      it 'returns the expected values' do
        expect(list1.wip_limits_available?).to be_truthy
        expect(list2.wip_limits_available?).to be_truthy
      end
    end

    context 'with disabled wip_limits' do
      before do
        stub_licensed_features(wip_limits: false)
      end

      it 'returns the expected values' do
        expect(list1.wip_limits_available?).to be_falsy
        expect(list2.wip_limits_available?).to be_falsy
      end
    end
  end
end
