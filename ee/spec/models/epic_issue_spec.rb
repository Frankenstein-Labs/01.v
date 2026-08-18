# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicIssue, feature_category: :portfolio_management do
  let_it_be(:ancestor) { create(:group) }
  let_it_be(:group) { create(:group, parent: ancestor) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:issue2) { create(:issue, project: project) }

  describe 'scopes' do
    let_it_be(:epic_issue1) { create(:epic_issue, epic: epic, issue: issue) }
    let_it_be(:epic_issue2) { create(:epic_issue, epic: epic, issue: issue2) }

    describe '.for_issue' do
      it 'only returns epic issues for the given issues' do
        expect(described_class.for_issue([epic_issue1.issue.id])).to match_array([epic_issue1])
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:work_item) }
    it { is_expected.to belong_to(:namespace) }

    it do
      is_expected.to belong_to(:work_item_parent_link).class_name('WorkItems::ParentLink').inverse_of(:epic_issue)
    end
  end

  describe 'validations' do
    let(:epic) { build(:epic, group: group) }
    let(:confidential_epic) { build(:epic, :confidential, group: group) }
    let(:issue) { build(:issue, project: project) }
    let(:confidential_issue) { build(:issue, :confidential, project: project) }

    context 'work_item_parent_link' do
      it { is_expected.to validate_presence_of(:work_item_parent_link) }
    end

    it 'is valid to add non-confidential issue to non-confidential epic' do
      expect(build(:epic_issue, epic: epic, issue: issue)).to be_valid
    end

    it 'is valid to add confidential issue to confidential epic' do
      expect(build(:epic_issue, epic: confidential_epic, issue: confidential_issue)).to be_valid
    end

    it 'is valid to add confidential issue to non-confidential epic' do
      expect(build(:epic_issue, epic: epic, issue: confidential_issue)).to be_valid
    end

    it 'is not valid to add non-confidential issue to confidential epic' do
      expect(build(:epic_issue, epic: confidential_epic, issue: issue)).not_to be_valid
    end

    context 'when epic and issue belong to different organizations' do
      let_it_be(:other_organization) { create(:organization) }
      let_it_be(:other_group) { create(:group, organization: other_organization) }
      let_it_be(:other_project) { create(:project, group: other_group) }
      let_it_be(:cross_org_issue) { create(:issue, project: other_project) }

      subject(:epic_issue) { build(:epic_issue, epic: epic, issue: cross_org_issue) }

      it 'is invalid' do
        expect(epic_issue).not_to be_valid
        expect(epic_issue.errors[:issue]).to include('must belong to the same organization.')
      end

      context 'when the prevent_cross_organization_work_item_actions flag is disabled' do
        before do
          stub_feature_flags(prevent_cross_organization_work_item_actions: false)
        end

        it 'does not add the organization error' do
          epic_issue.valid?

          expect(epic_issue.errors[:issue]).not_to include('must belong to the same organization.')
        end
      end
    end

    context 'group hierarchy' do
      let(:issue) { build(:issue, project: project) }
      let(:work_item_parent_link) do
        build(:parent_link, work_item_id: issue.id, work_item_parent_id: epic.work_item.id)
      end

      subject { described_class.new(epic: epic, issue: issue, work_item_parent_link: work_item_parent_link) }

      context 'when epic and issue are from different group hierarchies' do
        let_it_be(:issue) { create(:issue) }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when epic and issue belong to the same group' do
        it { is_expected.to be_valid }
      end

      context 'when epic is in an ancestor group' do
        let_it_be_with_refind(:project) { create(:project, group: create(:group, parent: group)) }

        it { is_expected.to be_valid }
      end

      context 'when epic is in a descendant group' do
        let_it_be(:project) { create(:project, group: ancestor) }

        it { is_expected.to be_valid }
      end
    end

    context 'work items parent link' do
      let_it_be_with_reload(:issue) { create(:issue, project: project) }

      subject { described_class.new(epic: epic, issue: issue) }

      it 'is not valid without a work_item_parent_link' do
        expect(subject).to be_invalid
      end

      it 'is valid for issue with work item parent synced to the epic' do
        legacy_epic = create(:epic, :with_synced_work_item, group: group)
        work_item_epic = legacy_epic.work_item
        parent_link = create(:parent_link, work_item_parent: work_item_epic, work_item: WorkItem.find(issue.id))

        expect(described_class.new(epic: legacy_epic, issue: issue, work_item_parent_link: parent_link)).to be_valid
      end

      it 'is not valid for an issue with a parent link epic', :aggregate_failures do
        work_item_epic = create(:work_item, :epic, project: project)
        create(:parent_link, work_item_parent: work_item_epic, work_item: WorkItem.find(issue.id))

        expect(subject).to be_invalid
        expect(subject.errors.full_messages).to include('Issue already assigned to an epic')
      end

      context 'when work_item_syncing is set' do
        it 'skips the validation' do
          work_item_epic = create(:work_item, :epic, project: project)
          parent_link = create(:parent_link, work_item_parent: work_item_epic, work_item: WorkItem.find(issue.id))

          epic_issue = described_class.new(epic: epic, issue: issue, work_item_parent_link: parent_link)
          epic_issue.work_item_syncing = true

          expect(epic_issue).to be_valid
        end
      end
    end
  end

  context "relative positioning" do
    it_behaves_like "a class that supports relative positioning" do
      let(:factory) { :epic_tree_node }
      let(:default_params) { { parent: epic, group: epic.group } }

      def as_item(item)
        item.epic_tree_node_identity
      end
    end

    context 'with a mixed tree level' do
      let_it_be_with_reload(:left) { create(:epic_issue, epic: epic, issue: issue, relative_position: 100) }
      let_it_be_with_reload(:middle) { create(:epic, group: group, parent: epic, relative_position: 101) }
      let_it_be_with_reload(:right) { create(:epic_issue, epic: epic, issue: issue2, relative_position: 102) }

      context 'when relative position is set' do
        it 'can create space to the right' do
          left.class.mover.context(middle).shift_right
          [left, middle, right].each(&:reset)

          expect(middle.relative_position - left.relative_position).to be > 1
          expect(left.relative_position).to be < middle.relative_position
          expect(middle.relative_position).to be < right.relative_position
        end

        it 'can create space to the left' do
          right.class.mover.context(middle).shift_left
          [left, middle, right].each(&:reset)

          expect(right.relative_position - middle.relative_position).to be > 1
          expect(left.relative_position).to be < middle.relative_position
          expect(middle.relative_position).to be < right.relative_position
        end
      end

      it 'moves nulls to the end' do
        leaves = Array.new(2).map do
          create(:epic_issue, epic: epic, issue: create(:issue, project: project), relative_position: nil)
        end

        nested = create(:epic, group: epic.group, parent: epic, relative_position: nil)
        moved = [*leaves, nested]
        level = [nested, *leaves, right]

        expect do
          described_class.move_nulls_to_end(level)
        end.not_to change { right.reset.relative_position }

        moved.each(&:reset)

        expect(moved.map(&:relative_position)).to all(be > right.relative_position)
      end
    end
  end

  describe '.find_or_initialize_from_parent_link' do
    let_it_be(:work_item) { create(:work_item, :issue, project: project) }
    let_it_be(:parent_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

    subject(:epic_issue) { described_class.find_or_initialize_from_parent_link(parent_link) }

    context 'when epic issue does not exist' do
      let_it_be(:parent_link) { create(:parent_link, work_item_parent: parent_work_item, work_item: work_item) }

      it 'initializes a new epic issue with correct attributes', :aggregate_failures do
        expect(epic_issue.issue_id).to eq(work_item.id)
        expect(epic_issue.epic).to eq(parent_work_item.synced_epic)
        expect(epic_issue.work_item_parent_link).to eq(parent_link)
      end
    end

    context 'when epic issue already exists' do
      let_it_be(:existing_epic_issue) do
        create(:epic_issue, issue: Issue.find(work_item.id), epic: parent_work_item.synced_epic)
      end

      let(:parent_link) { existing_epic_issue.work_item_parent_link }

      it 'finds the existing epic issue and updates its attributes', :aggregate_failures do
        expect(epic_issue.id).to eq(existing_epic_issue.id)
        expect(epic_issue.issue_id).to eq(work_item.id)
        expect(epic_issue.epic).to eq(parent_work_item.synced_epic)
        expect(epic_issue.work_item_parent_link).to eq(parent_link)
      end
    end
  end

  describe '#update_cached_metadata' do
    it 'schedules cache update for epic when new issue is added' do
      expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([epic.id]).once

      create(:epic_issue, epic: epic, issue: issue)
    end

    context 'when epic issue already exists' do
      let_it_be_with_reload(:epic_issue) { create(:epic_issue, epic: epic, issue: issue) }

      it 'schedules cache update for epic when epic issue is updated' do
        new_epic = create(:epic, group: group)

        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([epic.id]).once
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([new_epic.id]).once

        epic_issue.work_item_syncing = true

        epic_issue.update!(epic: new_epic)
      end

      it 'schedules cache update for epic when epic issue is destroyed' do
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([epic.id]).once

        epic_issue.destroy!
      end
    end
  end

  describe '#exportable_record?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:private_group) { create(:group, :private) }
    let_it_be(:private_epic) { create(:epic, group: private_group) }
    let_it_be(:epic_issue) { create(:epic_issue, epic: private_epic, issue: issue) }

    subject { epic_issue.exportable_record?(current_user) }

    before do
      stub_licensed_features(epics: true)
    end

    context 'when user is nil' do
      let(:current_user) { nil }

      it { is_expected.to be_falsey }
    end

    context 'when user cannot read epic' do
      let(:current_user) { user }

      it { is_expected.to be_falsey }
    end

    context 'when user can read epic' do
      let(:current_user) { user }

      before_all do
        private_group.add_reporter(user)
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#validate_max_children' do
    let(:epic) { create(:epic) }
    let(:issue) { create(:issue) }
    let(:epic_issue) { build(:epic_issue, epic: epic, issue: issue) }
    let(:error) do
      _('cannot be linked to the epic. This epic already has maximum number of child issues & epics.')
    end

    context 'when the epic has not reached the maximum number of children' do
      it 'does not add an error' do
        allow(epic).to receive(:max_children_count_achieved?).and_return(false)

        epic_issue.valid?

        expect(epic_issue.errors[:issue]).to be_empty
      end
    end

    context 'when the epic has reached the maximum number of children' do
      it 'adds an error' do
        allow(epic).to receive(:max_children_count_achieved?).and_return(true)

        epic_issue.valid?

        expect(epic_issue.errors[:issue]).to include(error)
      end
    end

    context 'when either epic or issue is nil' do
      it 'does not add an error' do
        epic_issue.epic = nil
        epic_issue.valid?
        expect(epic_issue.errors[:issue]).not_to include(error)

        epic_issue.epic = epic
        epic_issue.issue = nil
        epic_issue.valid?
        expect(epic_issue.errors[:issue]).not_to include(error)
      end
    end
  end
end
