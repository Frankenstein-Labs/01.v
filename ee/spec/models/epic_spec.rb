# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Epic, feature_category: :portfolio_management do
  include NestedEpicsHelper
  include LegacyEpicsHelper

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:descendant_group) { create(:group, parent: group) }
  let_it_be(:project) { create(:project, group: group) }

  describe 'associations' do
    subject { build(:epic) }

    it { is_expected.to belong_to(:author).class_name('User') }
    it { is_expected.to belong_to(:assignee).class_name('User') }
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:parent) }
    it { is_expected.to belong_to(:work_item).with_foreign_key('issue_id').inverse_of(:synced_epic) }

    it do
      is_expected.to belong_to(:work_item_parent_link).class_name('WorkItems::ParentLink')
        .optional(true).inverse_of(:epic)
    end

    it { is_expected.to have_many(:epic_issues) }
    it { is_expected.to have_many(:user_mentions).class_name('EpicUserMention') }
    it { is_expected.to have_many(:boards_epic_user_preferences).class_name('Boards::EpicUserPreference').inverse_of(:epic) }
    it { is_expected.to have_many(:epic_board_positions).class_name('Boards::EpicBoardPosition').inverse_of(:epic) }

    context 'award_emoji' do
      let_it_be_with_refind(:epic) { create(:epic) }
      let_it_be_with_refind(:work_item) { epic.work_item }
      let_it_be(:emoji_1) { create(:award_emoji, :upvote, awardable: work_item, user: create(:user)) }
      let_it_be(:emoji_2) { create(:award_emoji, :downvote, awardable: epic, user: create(:user)) }

      it 'delegates award emoji to work item', :aggregate_failures do
        expect(epic.award_emoji.pluck(:name)).to match_array([AwardEmoji::THUMBS_UP, AwardEmoji::THUMBS_DOWN])
        expect(work_item.award_emoji.pluck(:name)).to match_array([AwardEmoji::THUMBS_UP, AwardEmoji::THUMBS_DOWN])
      end

      it 'reads participants from award emoji on work item' do
        expect(epic.participants).to match_array([epic.author, emoji_1.user, emoji_2.user])
        expect(work_item.participants).to match_array([work_item.author, emoji_1.user, emoji_2.user])
      end

      describe '#find' do
        it 'delegates find to work item award emoji' do
          expect(epic.award_emoji.find(emoji_1.id)).to eq(emoji_1)
          expect(epic.award_emoji.find(emoji_2.id)).to eq(emoji_2)
          expect(work_item.award_emoji.find(emoji_1.id)).to eq(emoji_1)
          expect(work_item.award_emoji.find(emoji_2.id)).to eq(emoji_2)
        end
      end

      context 'when epic is deleted' do
        let_it_be_with_refind(:epic) { create(:epic) }
        let_it_be_with_reload(:work_item) { epic.work_item }
        let_it_be(:emoji_1) { create(:award_emoji, awardable: work_item) }
        let_it_be(:emoji_2) { create(:award_emoji, awardable: work_item) }
        let_it_be(:emoji_3) { create(:award_emoji, awardable: work_item) }
        let_it_be(:emoji_4) { create(:award_emoji) } # Not to be deleted

        it 'deletes award emoji when work item is destroyed' do
          expect { epic.destroy! }.to change { ::AwardEmoji.count }.by(-3)
          expect(emoji_4.reload).to be_persisted
        end
      end
    end
  end

  describe 'default values' do
    it { expect(subject.color).to eq(Epic::DEFAULT_COLOR) }
  end

  describe 'scopes' do
    let_it_be(:confidential_epic) { create(:epic, confidential: true, group: group, title: 'Foo 1') }
    let_it_be(:public_epic) { create(:epic, group: group, title: 'Foo 2') }

    describe '.public_only' do
      it 'only returns public epics' do
        expect(described_class.public_only).to eq([public_epic])
      end
    end

    describe '.confidential' do
      it 'only returns confidential epics' do
        expect(described_class.confidential).to eq([confidential_epic])
      end
    end

    describe '.not_confidential_or_in_groups' do
      it 'returns only epics which are either not confidential or in the group' do
        create(:epic, confidential: true)

        expect(described_class.not_confidential_or_in_groups(group)).to match_array([confidential_epic, public_epic])
      end
    end

    describe 'relative position scopes' do
      let_it_be(:board) { create(:epic_board) }
      let_it_be(:other_board) { create(:epic_board) }
      let_it_be(:epic1) { create(:epic) }
      let_it_be(:epic2) { create(:epic) }
      let_it_be(:epic3) { create(:epic) }

      let_it_be(:position1) { create(:epic_board_position, epic: epic1, epic_board: board, relative_position: 20) }
      let_it_be(:position2) { create(:epic_board_position, epic: epic2, epic_board: board, relative_position: 10) }
      let_it_be(:position3) { create(:epic_board_position, epic: epic3, epic_board: board, relative_position: 20) }
      # this position should be ignored because it's for other board:
      let_it_be(:position5) { create(:epic_board_position, epic: confidential_epic, epic_board: other_board, relative_position: 5) }

      describe '.order_relative_position_on_board' do
        it 'returns epics ordered by position on the board, null last' do
          epics = described_class.join_board_position(board.id).order_relative_position_on_board(board.id)

          expect(epics).to eq([epic2, epic3, epic1, public_epic, confidential_epic])
        end
      end

      describe 'without_board_position' do
        it 'returns only epics which do not have position set for the board' do
          epics = described_class.join_board_position(board.id).without_board_position(board.id)

          expect(epics).to match_array([confidential_epic, public_epic])
        end
      end

      describe '.join_board_position' do
        it 'returns epics with joined position for the board' do
          positions = described_class.join_board_position(board.id)
            .select('boards_epic_board_positions.relative_position as pos').map(&:pos)

          # confidential_epic and public_epic should have both nil position for the board
          expect(positions).to match_array([20, 10, 20, nil, nil])
        end
      end
    end

    describe 'title sort scopes' do
      let_it_be(:epic1) { create(:epic, title: 'foo') }
      let_it_be(:epic2) { create(:epic, title: 'bar') }
      let_it_be(:epic3) { create(:epic, title: 'baz') }
      let_it_be(:epic4) { create(:epic, title: 'Baz 2') }

      describe '.order_title_asc' do
        it 'returns epics ordered by title, ascending' do
          expect(described_class.order_title_asc).to eq([epic2, epic3, epic4, epic1, confidential_epic, public_epic])
        end

        describe '.order_title_desc' do
          it 'returns epics ordered by title, decending' do
            expect(described_class.order_title_desc).to eq([public_epic, confidential_epic, epic1, epic4, epic3, epic2])
          end
        end
      end
    end

    describe '.in_milestone' do
      let_it_be(:milestone) { create(:milestone, project: project) }

      it 'returns epics which have an issue in the milestone' do
        epic1 = create(:epic, group: group)
        epic2 = create(:epic, group: group)
        epic3 = create(:epic, group: group)
        create(:issue, project: project, milestone: milestone, epic: epic1)
        create(:issue, project: project, milestone: milestone, epic: epic2)
        create(:issue, project: project, epic: epic3)

        expect(described_class.in_milestone(milestone.id)).to match_array([epic1, epic2])
      end
    end

    describe '.in_work_item_parents' do
      let_it_be(:parent_epic) { create(:epic, group: group) }

      context 'with child epics' do
        let_it_be(:child_epic1) { create(:epic, group: group, parent: parent_epic) }
        let_it_be(:child_epic2) { create(:epic, group: group, parent: parent_epic) }
        let_it_be(:other_epic) { create(:epic, group: group) }

        it 'returns epics that are children of the given work item' do
          result = described_class.in_work_item_parents(parent_epic.issue_id)

          expect(result).to match_array([child_epic1, child_epic2])
          expect(result).not_to include(other_epic)
        end
      end

      context 'when work item has no children' do
        it 'returns empty relation' do
          result = described_class.in_work_item_parents(parent_epic.issue_id)

          expect(result).to be_empty
        end
      end

      context 'with nested epic hierarchies' do
        let(:grandparent_epic) { create(:epic, group: group) }
        let(:parent_epic) { create(:epic, group: group, parent: grandparent_epic) }
        let(:child_epic) { create(:epic, group: group, parent: parent_epic) }

        it 'returns only direct children for each level' do
          grandparent_children = described_class.in_work_item_parents(grandparent_epic.issue_id)
          parent_children = described_class.in_work_item_parents(parent_epic.issue_id)

          expect(grandparent_children).to contain_exactly(parent_epic)
          expect(parent_children).to contain_exactly(child_epic)
        end
      end
    end

    describe 'from_id' do
      let_it_be(:max_id) { described_class.maximum(:id) }
      let_it_be(:epic1) { create(:epic, id: max_id + 1) }
      let_it_be(:epic2) { create(:epic, id: max_id + 2) }
      let_it_be(:epic3) { create(:epic, id: max_id + 3) }

      it 'returns records with id bigger or equal to the provided param' do
        expect(described_class.from_id(epic2.id)).to match_array([epic2, epic3])
      end
    end

    describe '.preload_group_and_routables' do
      before_all do
        create(:epic, group: group)
      end

      subject(:preload_group_and_routables) do
        described_class.in_selected_groups(group).preload_group_and_routables
      end

      it { expect(preload_group_and_routables.first.association(:group)).to be_loaded }
      it { expect(preload_group_and_routables.first.group.association(:route)).to be_loaded }
      it { expect(preload_group_and_routables.first.group.association(:saml_provider)).to be_loaded }
      it { expect(preload_group_and_routables.first.group.association(:ip_restrictions)).to be_loaded }
    end

    describe '.order_by_hierarchy_order' do
      let_it_be(:group) { create(:group) }
      let_it_be(:root_epic) { create(:epic, group: group) }
      let_it_be(:ancestor_epic) { create(:epic, group: group, parent: root_epic) }
      let_it_be(:parent_epic) { create(:epic, group: group, parent: ancestor_epic) }
      let_it_be(:child_epic) { create(:epic, group: group, parent: parent_epic) }
      let_it_be(:other_epic1) { create(:epic, group: group) }
      let_it_be(:other_epic2) { create(:epic, group: group) }

      it 'returns epics ordered by hierarchy position' do
        epics = described_class.where(id: [root_epic.id, ancestor_epic.id, parent_epic.id])
                               .order_by_hierarchy_order(child_epic)

        expect(epics).to eq([parent_epic, ancestor_epic, root_epic])
      end

      it 'includes the child epic if it is in the where clause' do
        epics = described_class.where(id: [root_epic.id, ancestor_epic.id, parent_epic.id, child_epic.id])
                               .order_by_hierarchy_order(child_epic)

        expect(epics.map(&:id)).to include(child_epic.id)
      end

      context 'when child epic has no ancestors' do
        it 'returns the original scope' do
          epics = described_class.where(id: other_epic1.id).order_by_hierarchy_order(other_epic1)

          expect(epics).to eq([other_epic1])
        end
      end

      context 'when ancestor_ids is blank' do
        it 'returns the original scope' do
          allow(other_epic1).to receive(:work_item_ancestors_ids).and_return([])
          epics = described_class.where(id: other_epic1.id).order_by_hierarchy_order(other_epic1)

          expect(epics).to eq([other_epic1])
        end
      end

      context 'when ancestor_ids has only one element' do
        it 'returns the original scope' do
          allow(parent_epic).to receive(:work_item_ancestors_ids).and_return([root_epic.issue_id])
          epics = described_class.where(id: parent_epic.id).order_by_hierarchy_order(parent_epic)

          expect(epics).to eq([parent_epic])
        end
      end

      context 'when hierarchy_order parameter is provided' do
        it 'returns epics ordered by hierarchy position ascending' do
          epics = described_class.where(id: [root_epic.id, ancestor_epic.id, parent_epic.id])
                                 .order_by_hierarchy_order(child_epic, hierarchy_order: :asc)

          expect(epics).to eq([parent_epic, ancestor_epic, root_epic])
        end

        it 'returns epics ordered by hierarchy position descending' do
          epics = described_class.where(id: [root_epic.id, ancestor_epic.id, parent_epic.id])
                                 .order_by_hierarchy_order(child_epic, hierarchy_order: :desc)

          expect(epics).to eq([root_epic, ancestor_epic, parent_epic])
        end

        it 'returns the original scope when child has no ancestors and hierarchy_order is provided' do
          epics = described_class.where(id: other_epic1.id)
                                 .order_by_hierarchy_order(other_epic1, hierarchy_order: :desc)

          expect(epics).to eq([other_epic1])
        end
      end
    end
  end

  describe 'validations' do
    subject { build(:epic) }

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:work_item) }

    context 'when parent is set' do
      subject { build(:epic, parent: build(:epic)) }

      it { is_expected.to validate_presence_of(:work_item_parent_link) }

      context 'when epic parent is not the same as the work item parent' do
        let_it_be(:parent_epic) { create(:epic) }
        let_it_be(:other_epic) { create(:epic) }
        let_it_be(:child_epic, freeze: false) { build(:epic, parent: parent_epic) }

        before do
          child_epic.work_item_parent_link.work_item_parent = other_epic.work_item
        end

        it 'errors' do
          expect(::Gitlab::EpicWorkItemSync::Logger).to receive(:error).with({
            message: 'Work item epic parent mismatch',
            work_item_parent_link_id: child_epic.work_item_parent_link.id,
            epic_parent_id: parent_epic.id
          })

          expect(child_epic.save).to be(false)
          expect(child_epic.errors[:parent]).to include("Epic and its work item parent must be the same")
        end
      end
    end

    context 'when parent is not set' do
      it { is_expected.not_to validate_presence_of(:work_item_parent_link) }
    end

    it { is_expected.to validate_presence_of(:total_opened_issue_weight) }
    it { is_expected.to validate_presence_of(:total_closed_issue_weight) }
    it { is_expected.to validate_presence_of(:total_opened_issue_count) }
    it { is_expected.to validate_presence_of(:total_closed_issue_count) }

    it { is_expected.to validate_numericality_of(:total_opened_issue_weight).only_integer }
    it { is_expected.to validate_numericality_of(:total_closed_issue_weight).only_integer }
    it { is_expected.to validate_numericality_of(:total_opened_issue_count).only_integer }
    it { is_expected.to validate_numericality_of(:total_closed_issue_count).only_integer }

    it 'is valid with a valid parent' do
      epic = build(:epic, group: group, parent: create(:epic, group: group))

      expect(epic).to be_valid
    end

    it 'is valid if epic is confidential and has only confidential issues' do
      epic = create(:epic, :confidential, group: group)
      create(:issue, :confidential, project: project, epic: epic)

      expect(epic).to be_valid
    end

    it 'is not valid if epic is confidential and has non-confidential issues' do
      epic = create(:epic, group: group)
      create(:issue, project: project, epic: epic)

      epic.confidential = true

      expect(epic).not_to be_valid
    end

    it 'is valid if epic is confidential and has only confidential subepics' do
      epic = create(:epic, group: group)
      create(:epic, :confidential, parent: epic, group: group)

      epic.confidential = true

      expect(epic).to be_valid
    end

    it 'is not valid if epic is confidential and has non-confidential subepics' do
      epic = create(:epic, group: group)
      create(:epic, parent: epic, group: group)

      epic.confidential = true

      expect(epic).not_to be_valid
    end

    describe 'children count' do
      let_it_be(:parent_epic) { create(:epic, group: group) }
      let_it_be_with_reload(:child_epic1) { create(:epic, group: group, parent: parent_epic) }
      let_it_be(:child_epic2) { create(:epic, group: group, parent: parent_epic) }
      let_it_be(:child_issue) { create(:issue, project: project, title: "Child") }
      let_it_be(:epic_issue) { create(:epic_issue, epic: parent_epic, issue: child_issue) }

      let(:error) { _('You cannot add any more epics. This epic already has maximum number of child issues & epics.') }

      subject(:epic) { build(:epic, group: group, parent: parent_epic) }

      it { is_expected.to be_valid }

      context 'when child count limit was reached' do
        before do
          stub_const("EE::#{described_class}::MAX_CHILDREN_COUNT", 2)
        end

        it 'is not valid' do
          expect(epic).not_to be_valid
          expect(epic.errors[:parent]).to match_array([error])
        end

        it 'already assigned epics are still valid' do
          expect(child_epic1).to be_valid
        end

        it 'is valid when removing parent' do
          child_epic1.parent = nil

          expect(child_epic1).to be_valid
        end

        it 'is not valid when changing parents' do
          epic_with_other_parent = create(:epic, group: group, parent: create(:epic, group: group))
          expect(epic_with_other_parent).to be_valid

          epic_with_other_parent.work_item_parent_link = build(:parent_link, work_item_parent: parent_epic.work_item, work_item: epic_with_other_parent.work_item)
          epic_with_other_parent.parent = parent_epic

          expect(epic_with_other_parent).not_to be_valid
          expect(epic_with_other_parent.errors[:parent]).to match_array([error])
        end
      end
    end

    describe 'maximum hierarchy depth' do
      let_it_be(:group) { create(:group) }
      let_it_be_with_reload(:level_1) { create(:epic, group: group) }
      let_it_be_with_reload(:level_2) { create(:epic, parent: level_1, group: group) }
      let_it_be_with_reload(:level_3) { create(:epic, parent: level_2, group: group) }

      before do
        stub_const("EE::#{described_class}::MAX_HIERARCHY_DEPTH", 3)
      end

      context 'for a new epic' do
        subject(:create_epic) { build(:epic, group: group, parent: parent) }

        context 'when it below maximum depth' do
          let(:parent) { level_2 }

          it { is_expected.to be_valid }
        end

        context 'when goes above maximum depth' do
          let(:parent) { level_3 }
          let(:expected_error) { 'This epic cannot be added. One or more epics would exceed the maximum depth (3) from its most distant ancestor.' }

          it 'is invalid' do
            epic = create_epic

            expect(epic).to be_invalid
            expect(epic.errors[:parent]).to include(expected_error)
          end
        end
      end
    end

    %i[start_date start_date_fixed due_date due_date_fixed].each do |field|
      context 'for new records' do
        it "validates #{field} minimum value" do
          epic = build(:epic, field => WorkItems::DatesSource::MIN_DATE_LIMIT - 1.day)

          expect(epic).not_to be_valid
          expect(epic.errors[field]).to include('must be greater than or equal to 1000-01-01')
        end

        it "validates #{field} maximum value" do
          epic = build(:epic, field => WorkItems::DatesSource::MAX_DATE_LIMIT + 1.day)

          expect(epic).not_to be_valid
          expect(epic.errors[field]).to include('must be less than or equal to 9999-12-31')
        end
      end

      context 'for existing records' do
        it "validates #{field} only if it was updated", :aggregate_failures do
          epic = build(:epic, field => WorkItems::DatesSource::MAX_DATE_LIMIT + 1.day)
          epic.save!(validate: false)

          expect(epic).to be_valid

          epic[field] += 1.day
          expect(epic).not_to be_valid
          expect(epic.errors[field]).to include('must be less than or equal to 9999-12-31')
        end
      end
    end
  end

  describe '#max_children_count_achieved?' do
    let_it_be(:parent_epic) { create(:epic, group: group) }
    let_it_be(:child_epic1) { create(:epic, group: group, parent: parent_epic) }
    let_it_be(:child_epic2) { create(:epic, group: group, parent: parent_epic) }
    let_it_be(:child_issue1) { create(:issue, project: project, title: "Child") }
    let_it_be(:epic_issue) { create(:epic_issue, epic: parent_epic, issue: child_issue1) }

    before do
      stub_const("EE::#{described_class}::MAX_CHILDREN_COUNT", 4)
    end

    context 'when the epic has fewer than MAX_CHILDREN_COUNT children' do
      it 'returns false' do
        expect(parent_epic.max_children_count_achieved?).to be_falsey
      end
    end

    context 'when the epic has exactly MAX_CHILDREN_COUNT children' do
      it 'returns true' do
        child_issue2 = create(:issue, project: project, title: "Child")
        create(:epic_issue, epic: parent_epic, issue: child_issue2)

        expect(parent_epic.max_children_count_achieved?).to be_truthy
      end
    end
  end

  describe 'callbacks' do
    let_it_be(:group) { create(:group) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be_with_reload(:child_epic) { create(:epic, group: group, parent: epic, start_date: Date.new(1998, 1, 1), end_date: Date.new(1999, 1, 1)) }
    let_it_be(:another_epic) { create(:epic, group: group) }

    context 'when epic indexing is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        Epics::UpdateDatesService.new([epic, another_epic]).execute
        epic.reload
        another_epic.reload
      end

      it 'updates epics in Elasticsearch when the child epic start_date is updated' do
        expect(epic.start_date_sourcing_epic).to eq(child_epic)

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(another_epic)

        child_epic.update!(start_date: child_epic.start_date - 2.days)
      end

      it 'updates epics in Elasticsearch when the child epic end_date is updated' do
        expect(epic.due_date_sourcing_epic).to eq(child_epic)

        expect(::Elastic::ProcessBookkeepingService).to receive(:track!).with(epic).once
        expect(::Elastic::ProcessBookkeepingService).not_to receive(:track!).with(another_epic)

        child_epic.update!(end_date: child_epic.end_date + 2.days)
      end
    end
  end

  describe 'modules' do
    subject { described_class }

    it_behaves_like 'AtomicInternalId' do
      let(:group) { create(:group) }
      let(:internal_id_attribute) { :iid }
      let(:work_item) { create(:work_item, :group_level, namespace: group) }
      let(:instance) { build(:epic, group: group, work_item: work_item) }
      let(:scope) { :group }
      let(:scope_attrs) { { namespace: instance.group } }
      let(:usage) { :issues }
    end

    describe 'IID tracking during import' do
      let_it_be(:group, freeze: true) { create(:group) }
      let(:epic) { build(:epic, group: group) }

      context 'when iid is set externally' do
        before do
          epic.iid = 100
        end

        it 'calls InternalId.track_greatest' do
          expect(InternalId).to receive(:track_greatest).and_call_original

          epic.save!
        end

        context 'and importing is true' do
          before do
            epic.importing = true
          end

          it 'does not call InternalId.track_greatest' do
            expect(InternalId).not_to receive(:track_greatest)

            epic.save!
          end
        end
      end
    end
  end

  describe 'ordering' do
    let_it_be(:epic1) { create(:epic, start_date: 7.days.ago, end_date: 3.days.ago, updated_at: 3.days.ago, created_at: 7.days.ago, relative_position: 3, title: 'foo') }
    let_it_be(:epic2) { create(:epic, start_date: 3.days.ago, updated_at: 10.days.ago, created_at: 12.days.ago, relative_position: 1, title: 'bar') }
    let_it_be(:epic3) { create(:epic, end_date: 5.days.ago, updated_at: 5.days.ago, created_at: 6.days.ago, relative_position: 2, title: 'baz') }
    let_it_be(:epic4) { create(:epic, relative_position: 4, title: 'world') }

    def epics(order_by)
      described_class.order_by(order_by)
    end

    it 'orders by start_or_end_date' do
      expect(epics(:start_or_end_date)).to eq([epic4, epic1, epic3, epic2])
    end

    it 'orders by start_date ASC' do
      expect(epics(:start_date_asc)).to eq([epic1, epic2, epic4, epic3])
    end

    it 'orders by start_date DESC' do
      expect(epics(:start_date_desc)).to eq([epic2, epic1, epic4, epic3])
    end

    it 'orders by end_date ASC' do
      expect(epics(:end_date_asc)).to eq([epic3, epic1, epic4, epic2])
    end

    it 'orders by end_date DESC' do
      expect(epics(:end_date_desc)).to eq([epic1, epic3, epic4, epic2])
    end

    it 'orders by updated_at ASC' do
      expect(epics(:updated_asc)).to eq([epic2, epic3, epic1, epic4])
    end

    it 'orders by updated_at DESC' do
      expect(epics(:updated_desc)).to eq([epic4, epic1, epic3, epic2])
    end

    it 'orders by created_at ASC' do
      expect(epics(:created_asc)).to eq([epic2, epic1, epic3, epic4])
    end

    it 'orders by created_at DESC' do
      expect(epics(:created_desc)).to eq([epic4, epic3, epic1, epic2])
    end

    it 'orders by relative_position ASC' do
      expect(epics(:relative_position)).to eq([epic2, epic3, epic1, epic4])
    end

    it 'orders by title ASC' do
      expect(epics(:title_asc)).to eq([epic2, epic3, epic1, epic4])
    end

    it 'orders by title DESC' do
      expect(epics(:title_desc)).to eq([epic4, epic1, epic3, epic2])
    end
  end

  describe '#valid_parent?' do
    context 'basic checks' do
      let(:epic) { build(:epic, group: group) }

      it 'returns true without parent' do
        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns true with a valid parent' do
        epic.parent = create(:epic, group: group)

        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns false when level is too deep' do
        epic1 = create(:epic, group: group)
        add_parents_to(epic: epic1, count: 6)

        epic.parent = epic1
        epic1.reload
        expect(epic.valid_parent?).to be_falsey
      end

      context 'with parent in a descendant group' do
        let_it_be(:parent_epic) { create(:epic, group: descendant_group) }

        it 'returns true' do
          epic.parent = parent_epic

          expect(epic.valid_parent?).to be_truthy
        end
      end

      context 'with parent from a different group hierarchy' do
        let_it_be(:other_group) { create(:group) }
        let_it_be(:other_epic) { create(:epic, group: other_group) }

        it 'returns true' do
          epic.parent = other_epic

          expect(epic.valid_parent?).to be_truthy
        end
      end
    end

    context 'when adding an Epic that has existing children' do
      let_it_be(:parent_epic) { create(:epic, group: group) }

      let(:epic) { build(:epic, group: group) }

      it 'returns true when total depth after adding will not exceed limit' do
        create(:epic, group: group, parent: epic)

        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns false when total depth after adding would exceed limit' do
        add_children_to(epic: epic, count: 6)

        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_falsey
      end
    end

    context 'when parent has ancestors and epic has children' do
      let_it_be_with_refind(:root_epic) { create(:epic, group: group) }
      let_it_be(:parent_epic) { create(:epic, group: group, parent: root_epic) }

      let(:epic) { build(:epic, group: group) }
      let(:child_epic1) { create(:epic, group: group, parent: epic) }

      it 'returns true when total depth after adding will not exceed limit' do
        epic.parent = parent_epic

        expect(epic.valid_parent?).to be_truthy
      end

      it 'returns false when total depth after adding would exceed limit' do
        add_parents_to(epic: root_epic, count: 2)
        add_children_to(epic: child_epic1, count: 2)

        epic.work_item_parent_link = build(:parent_link, work_item_parent: parent_epic.work_item, work_item: epic.work_item)
        epic.parent = parent_epic
        parent_epic.reload

        expect(epic.valid_parent?).to be_falsey
      end
    end

    context 'when hierarchy is cyclic' do
      let(:epic) { create(:epic, group: group) }

      it 'returns false when parent is same as the epic' do
        epic.parent = epic

        expect(epic.valid_parent?).to be_falsey
      end

      it 'returns false when child epic is parent of the given parent' do
        epic1 = create(:epic, group: group, parent: epic)
        epic.parent = epic1
        epic1.reload
        expect(epic.valid_parent?).to be_falsey
      end

      it 'returns false when child epic is an ancestor of the given parent' do
        epic1 = create(:epic, group: group, parent: epic)
        epic2 = create(:epic, group: group, parent: epic1)
        epic.parent = epic2
        epic2.reload
        expect(epic.valid_parent?).to be_falsey
      end
    end
  end

  context 'hierarchy' do
    let_it_be_with_reload(:epic1) { create(:epic, group: group) }
    let_it_be_with_reload(:epic2) { create(:epic, group: group, parent: epic1) }
    let_it_be_with_reload(:epic3) { create(:epic, group: group, parent: epic2) }
    let_it_be_with_reload(:epic4) { create(:epic, group: group, parent: epic3) }

    describe '#work_item_ancestors' do
      it 'returns all ancestors for an epic ordered correctly' do
        expect(epic4.work_item_ancestors).to match_array([epic3, epic2, epic1])
      end

      it 'returns an empty array if an epic does not have any parent' do
        expect(epic1.work_item_ancestors).to be_empty
      end
    end

    describe '#work_item_ancestors_ids_with_order' do
      it 'returns all ancestor IDs in ascending order by default' do
        ancestor_ids = epic4.work_item_ancestors_ids_with_order

        expect(ancestor_ids).to eq([epic3.issue_id, epic2.issue_id, epic1.issue_id])
      end

      it 'returns all ancestor IDs in ascending order when explicitly specified' do
        ancestor_ids = epic4.work_item_ancestors_ids_with_order(hierarchy_order: :asc)

        expect(ancestor_ids).to eq([epic3.issue_id, epic2.issue_id, epic1.issue_id])
      end

      it 'returns all ancestor IDs in descending order' do
        ancestor_ids = epic4.work_item_ancestors_ids_with_order(hierarchy_order: :desc)

        expect(ancestor_ids).to eq([epic1.issue_id, epic2.issue_id, epic3.issue_id])
      end

      it 'returns an empty array if an epic does not have any parent' do
        expect(epic1.work_item_ancestors_ids_with_order).to be_empty
      end

      it 'returns work item IDs, not epic IDs' do
        ancestor_ids = epic4.work_item_ancestors_ids_with_order

        expect(ancestor_ids).to all(be_a(Integer))
        expect(ancestor_ids).not_to include(epic3.id, epic2.id, epic1.id)
        expect(ancestor_ids).to include(epic3.issue_id, epic2.issue_id, epic1.issue_id)
      end

      context 'with different hierarchy depths' do
        it 'returns correct order for shallow hierarchy' do
          ancestor_ids = epic2.work_item_ancestors_ids_with_order

          expect(ancestor_ids).to eq([epic1.issue_id])
        end
      end
    end
  end

  describe '#upcoming?' do
    it 'returns true when start_date is in the future' do
      epic = build(:epic, start_date: 1.month.from_now)

      expect(epic.upcoming?).to be_truthy
    end

    it 'returns false when start_date is in the past' do
      epic = build(:epic, start_date: Date.today.prev_year)

      expect(epic.upcoming?).to be_falsey
    end
  end

  describe '#expired?' do
    it 'returns true when due_date is in the past' do
      epic = build(:epic, end_date: Date.today.prev_year)

      expect(epic.expired?).to be_truthy
    end

    it 'returns false when due_date is in the future' do
      epic = build(:epic, end_date: Date.today.next_year)

      expect(epic.expired?).to be_falsey
    end
  end

  describe '#start_date' do
    let(:date) { Date.new(2000, 1, 1) }

    context 'is set' do
      subject { build(:epic, :use_fixed_dates, start_date: date) }

      it 'returns as is' do
        expect(subject.start_date).to eq(date)
      end
    end
  end

  it_behaves_like 'within_timeframe scope' do
    let_it_be(:now) { Time.current }
    let_it_be(:group) { create(:group) }
    let_it_be(:resource_1) { create(:epic, group: group, start_date: now - 1.day, end_date: now + 1.day) }
    let_it_be(:resource_2) { create(:epic, group: group, start_date: now + 2.days, end_date: now + 3.days) }
    let_it_be(:resource_3) { create(:epic, group: group, end_date: now) }
    let_it_be(:resource_4) { create(:epic, group: group, start_date: now) }
  end

  describe '#start_date_from_milestones' do
    context 'fixed date' do
      it 'returns start date from start date sourcing milestone' do
        subject = create(:epic, :use_fixed_dates)
        milestone = create(:milestone, :with_dates)
        subject.start_date_sourcing_milestone = milestone

        expect(subject.start_date_from_milestones).to eq(milestone.start_date)
      end

      it 'keeps start date sourcing milestone when switching to fixed dates' do
        source_milestone = create(:milestone, :with_dates)
        epic = create(:epic, start_date_sourcing_milestone: source_milestone, start_date_is_fixed: false)

        expect { epic.update!(start_date_is_fixed: true) }.not_to change { epic.start_date_sourcing_milestone }
      end

      it 'keeps start date sourcing epic when switching to fixed dates' do
        source_epic = create(:epic, start_date: Time.current)
        epic = create(:epic, start_date_sourcing_epic: source_epic, start_date_is_fixed: false)

        expect { epic.update!(start_date_is_fixed: true) }.not_to change { epic.start_date_sourcing_epic }
      end
    end

    context 'milestone date' do
      it 'returns start_date' do
        subject = create(:epic, start_date: Date.new(2017, 3, 4))

        expect(subject.start_date_from_milestones).to eq(subject.start_date)
      end
    end
  end

  describe '#due_date_from_milestones' do
    context 'fixed date' do
      it 'returns due date from due date sourcing milestone' do
        subject = create(:epic, :use_fixed_dates)
        milestone = create(:milestone, :with_dates)
        subject.due_date_sourcing_milestone = milestone

        expect(subject.due_date_from_milestones).to eq(milestone.due_date)
      end

      it 'keeps due date sourcing milestone when switching to fixed dates' do
        source_milestone = create(:milestone, :with_dates)
        epic = create(:epic, due_date_sourcing_milestone: source_milestone, due_date_is_fixed: false)

        expect { epic.update!(due_date_is_fixed: true) }.not_to change { epic.due_date_sourcing_milestone }
      end

      it 'keeps due date sourcing epic when switching to fixed dates' do
        source_epic = create(:epic, due_date: Time.current)
        epic = create(:epic, due_date_sourcing_epic: source_epic, due_date_is_fixed: false)

        expect { epic.update!(due_date_is_fixed: true) }.not_to change { epic.due_date_sourcing_epic }
      end
    end

    context 'milestone date' do
      it 'returns due_date' do
        subject = create(:epic, due_date: Date.new(2017, 3, 4))

        expect(subject.due_date_from_milestones).to eq(subject.due_date)
      end
    end
  end

  describe '.deepest_relationship_level' do
    context 'when there are no epics' do
      it 'returns nil' do
        expect(described_class.deepest_relationship_level).to be_nil
      end
    end

    it 'returns the deepest relationship level between epics' do
      group_1 = create(:group)
      group_2 = create(:group)

      # No relationship
      create(:epic, group: group_1)

      # Two levels relationship
      group_1_epic_1 = create(:epic, group: group_1)
      create(:epic, group: group_1, parent: group_1_epic_1)

      # Three levels relationship
      group_2_epic_1 = create(:epic, group: group_2)
      group_2_epic_2 = create(:epic, group: group_2, parent: group_2_epic_1)
      create(:epic, group: group_2, parent: group_2_epic_2)

      expect(described_class.deepest_relationship_level).to eq(3)
    end
  end

  describe '#issues_readable_by' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:project2) { create(:project, group: group) }

    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:lone_issue) { create(:issue, project: project) }
    let_it_be(:other_issue) { create(:issue, project: project2) }
    let_it_be(:epic_issues) do
      [
        create(:epic_issue, epic: epic, issue: issue),
        create(:epic_issue, epic: epic, issue: other_issue)
      ]
    end

    let(:result) { epic.issues_readable_by(user) }

    it 'returns all issues if a user has access to them' do
      group.add_developer(user)

      expect(result.count).to eq(2)
      expect(result.map(&:id)).to match_array([issue.id, other_issue.id])
      expect(result.map(&:epic_issue_id)).to match_array(epic_issues.map(&:id))
    end

    it 'does not return issues user can not see' do
      project.add_developer(user)

      expect(result.count).to eq(1)
      expect(result.map(&:id)).to match_array([issue.id])
      expect(result.map(&:epic_issue_id)).to match_array([epic_issues.first.id])
    end
  end

  describe '#close' do
    subject(:epic) { create(:epic, state: 'opened') }

    it 'sets closed_at to Time.current when an epic is closed' do
      expect { epic.close }.to change { epic.closed_at }.from(nil)
    end

    it 'changes the state to closed' do
      expect { epic.close }.to change { epic.state }.from('opened').to('closed')
    end
  end

  describe '#reopen' do
    subject(:epic) { create(:epic, state: 'closed', closed_at: Time.current, closed_by: user) }

    it 'sets closed_at to nil when an epic is reopend' do
      expect { epic.reopen }.to change { epic.closed_at }.to(nil)
    end

    it 'sets closed_by to nil when an epic is reopend' do
      expect { epic.reopen }.to change { epic.closed_by }.from(user).to(nil)
    end

    it 'changes the state to opened' do
      expect { epic.reopen }.to change { epic.state }.from('closed').to('opened')
    end
  end

  describe '#to_reference' do
    let_it_be(:group) { create(:group, path: 'group-a') }
    let_it_be(:subgroup) { create(:group) }
    let_it_be(:group_project) { create(:project, group: group) }
    let_it_be(:subgroup_project) { create(:project, group: subgroup) }
    let_it_be(:other_project) { create(:project) }
    let_it_be(:epic) { create(:epic, iid: 1, group: group) }

    context 'when nil argument' do
      it 'returns epic id' do
        expect(epic.to_reference).to eq('&1')
      end
    end

    context 'when from argument equals epic group' do
      it 'returns epic id' do
        expect(epic.to_reference(epic.group)).to eq('&1')
      end
    end

    context 'when from argument is a group different from epic group' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(create(:group))).to eq('group-a&1')
      end
    end

    context 'when from argument is a project under the epic group' do
      it 'returns epic id' do
        expect(epic.to_reference(group_project)).to eq('&1')
      end
    end

    context 'when from argument is a project under the epic subgroup' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(subgroup_project)).to eq('group-a&1')
      end
    end

    context 'when from argument is a project in another group' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(other_project)).to eq('group-a&1')
      end
    end

    context 'when full is true' do
      it 'returns complete path to the epic' do
        expect(epic.to_reference(full: true)).to             eq('group-a&1')
        expect(epic.to_reference(epic.group, full: true)).to eq('group-a&1')
        expect(epic.to_reference(group, full: true)).to      eq('group-a&1')
        expect(epic.to_reference(group_project, full: true)).to eq('group-a&1')
      end
    end

    it 'avoids additional SQL queries' do
      epic # pre-create the epic

      recorder = ActiveRecord::QueryRecorder.new { epic.to_reference(project) }

      expect(recorder.count).to be_zero
    end
  end

  describe '#has_children?' do
    let_it_be_with_reload(:epic) { create(:epic, group: group) }

    it 'has no children' do
      expect(epic.has_children?).to be_falsey
    end

    it 'has child epics' do
      create(:epic, group: group, parent: epic)

      expect(epic.reload.has_children?).to be_truthy
    end
  end

  describe '#children' do
    let_it_be_with_reload(:epic) { create(:epic, group: group) }

    it 'returns empty relation when epic has no children' do
      expect(epic.children).to be_empty
    end

    it 'returns direct child epics' do
      child1 = create(:epic, group: group, parent: epic)
      child2 = create(:epic, group: group, parent: epic)
      child3 = create(:epic, group: group, parent: epic)

      children = epic.reload.children

      expect(children).to match_array([child1, child2, child3])
    end

    it 'does not include grandchildren epics' do
      child = create(:epic, group: group, parent: epic)
      grandchild = create(:epic, group: group, parent: child)

      children = epic.reload.children

      expect(children).to contain_exactly(child)
      expect(children).not_to include(grandchild)
    end

    it 'returns only epics, not issues' do
      child_epic = create(:epic, group: group, parent: epic)
      issue = create(:issue, project: project)
      create(:epic_issue, epic: epic, issue: issue)

      children = epic.reload.children

      expect(children).to contain_exactly(child_epic)
    end

    it 'returns correct children after parent reassignment' do
      original_parent = create(:epic, group: group)
      new_parent = create(:epic, group: group)
      child = create(:epic, group: group, parent: original_parent)

      expect(original_parent.reload.children).to include(child)
      expect(new_parent.reload.children).not_to include(child)

      child.work_item_parent_link.update!(work_item_parent: new_parent.work_item)
      child.update!(parent: new_parent)

      expect(original_parent.reload.children).not_to include(child)
      expect(new_parent.reload.children).to include(child)
    end

    it 'handles multiple children updates correctly' do
      child1 = create(:epic, group: group, parent: epic)
      child2 = create(:epic, group: group, parent: epic)

      expect(epic.reload.children.count).to eq(2)

      child1.destroy!

      expect(epic.reload.children).to contain_exactly(child2)
    end

    it 'returns children from same group' do
      child = create(:epic, group: group, parent: epic)

      expect(epic.reload.children).to include(child)
    end

    it 'returns children from descendant groups' do
      child = create(:epic, group: descendant_group, parent: epic)

      expect(epic.reload.children).to include(child)
    end
  end

  describe '#has_issues?' do
    let_it_be_with_reload(:epic) { create(:epic, group: group) }

    it 'has no issues' do
      expect(epic.has_issues?).to be_falsey
    end

    it 'has child issues' do
      create(:epic_issue, epic: epic, issue: create(:issue, project: project))

      expect(epic.has_issues?).to be_truthy
    end
  end

  describe '#has_parent?' do
    let_it_be_with_reload(:epic) { create(:epic, group: group) }

    it 'has no parent' do
      expect(epic.has_parent?).to be_falsey
    end

    it 'has parent' do
      parent_epic = create(:epic, group: group)

      epic.parent_id = parent_epic.id
      expect(epic.has_parent?).to be_truthy
    end
  end

  context 'mentioning other objects' do
    let(:epic) { create(:epic, group: group) }

    let(:project) { create(:project, :repository, :public) }
    let(:mentioned_issue) { create(:issue, project: project) }
    let(:mentioned_mr)     { create(:merge_request, source_project: project) }
    let(:mentioned_commit) { project.commit("HEAD~1") }

    let(:backref_text) { "epic #{epic.to_reference}" }
    let(:ref_text) do
      <<-MSG.strip_heredoc
        These are simple references:
          Issue:  #{mentioned_issue.to_reference(group)}
          Merge Request:  #{mentioned_mr.to_reference(group)}
          Commit: #{mentioned_commit.to_reference(group)}

        This is a self-reference and should not be mentioned at all:
          Self: #{backref_text}
      MSG
    end

    before do
      epic.update!(description: ref_text)
    end

    it 'creates new system notes for cross references' do
      [mentioned_issue, mentioned_mr, mentioned_commit].each do |newref|
        expect(SystemNoteService).to receive(:cross_reference)
          .with(newref, epic, epic.author)
      end

      epic.create_new_cross_references!(epic.author)
    end
  end

  context "relative positioning" do
    let_it_be(:group) { create(:group) }
    let_it_be(:parent) { create(:epic, group: group) }

    context 'there is no parent' do
      let_it_be(:factory) { :epic }
      let_it_be(:default_params) { { group: group } }

      it_behaves_like "no-op relative positioning"
    end

    context 'there is a parent' do
      it_behaves_like "a class that supports relative positioning" do
        let(:factory) { :epic_tree_node }
        let(:default_params) { { parent: parent, group: parent.group } }

        def as_item(item)
          item.epic_tree_node_identity
        end
      end
    end
  end

  context 'with existing epics and related issues' do
    let_it_be(:epic1) { create(:epic, group: group) }
    let_it_be(:epic2) { create(:epic, group: group, parent: epic1) }
    let_it_be(:epic3) { create(:epic, group: group, parent: epic2, state: :closed) }
    let_it_be(:epic4) { create(:epic, group: group) }
    let_it_be(:issue1) { create(:issue, weight: 2, project: project) }
    let_it_be(:issue2) { create(:issue, weight: 3, project: project) }
    let_it_be(:issue3) { create(:issue, state: :closed, project: project) }
    let_it_be(:epic_issue1) { create(:epic_issue, epic: epic2, issue: issue1, relative_position: 5) }
    let_it_be(:epic_issue2) { create(:epic_issue, epic: epic2, issue: issue2, relative_position: 2) }
    let_it_be(:epic_issue3) { create(:epic_issue, epic: epic3, issue: issue3) }

    describe '.related_issues' do
      it 'returns epic issues ordered by relative position' do
        result = described_class.related_issues(ids: [epic1.id, epic2.id])

        expect(result.pluck(:id)).to eq [issue2.id, issue1.id]
      end
    end

    describe '.ids_for_base_and_decendants' do
      it 'returns epic ids only for selected epics or its descendant epics' do
        create(:epic, group: group)

        expect(described_class.ids_for_base_and_decendants([epic1.id, epic4.id]))
          .to match_array([epic1.id, epic2.id, epic3.id, epic4.id])
      end
    end

    describe '.issue_metadata_for_epics' do
      it 'returns hash containing epic issues count and weight and epic status' do
        result = described_class.issue_metadata_for_epics(epic_ids: [epic2.id, epic3.id], limit: 100)

        expected = [{
          "epic_state_id" => 1,
          "id" => epic2.id,
          "iid" => epic2.iid,
          "issues_count" => 2,
          "issues_state_id" => 1,
          "issues_weight_sum" => 5,
          "parent_id" => epic1.id,
          "start_date" => epic2.start_date,
          "end_date" => epic2.end_date
        }, {
          "epic_state_id" => 2,
          "id" => epic3.id,
          "iid" => epic3.iid,
          "issues_count" => 1,
          "issues_state_id" => 2,
          "issues_weight_sum" => 0,
          "parent_id" => epic2.id,
          "start_date" => epic3.start_date,
          "end_date" => epic3.end_date
        }]
        expect(result).to match_array(expected)
      end

      context 'with multiple health statuses' do
        let_it_be(:issue4) { create(:issue, :opened, :on_track, project: project) }
        let_it_be(:issue5) { create(:issue, :opened, :needs_attention, project: project) }
        let_it_be(:issue6) { create(:issue, :opened, :at_risk, project: project) }
        let_it_be(:issue7) { create(:issue, :opened, :at_risk, project: project) }

        before do
          # Connect issues to epic 2
          create(:epic_issue, epic: epic2, issue: issue4)
          create(:epic_issue, epic: epic2, issue: issue5)
          create(:epic_issue, epic: epic2, issue: issue6)
          # Connect issues to epic 3
          create(:epic_issue, epic: epic3, issue: issue7)
        end

        it 'returns hash containing epic issues count, weight, epic status and epic issues health statuses' do
          result = described_class.issue_metadata_for_epics(epic_ids: [epic2.id, epic3.id], limit: 100, count_health_status: true)

          expected = [{
            "epic_state_id" => 1,
            "id" => epic2.id,
            "iid" => epic2.iid,
            "issues_count" => 5,
            "issues_state_id" => 1,
            "issues_weight_sum" => 5,
            "parent_id" => epic1.id,
            "issues_on_track" => 1,
            "issues_needs_attention" => 1,
            "issues_at_risk" => 1,
            "start_date" => epic2.start_date,
            "end_date" => epic2.end_date
          }, {
            "epic_state_id" => 2,
            "id" => epic3.id,
            "iid" => epic3.iid,
            "issues_count" => 1,
            "issues_state_id" => 2,
            "issues_weight_sum" => 0,
            "parent_id" => epic2.id,
            "issues_on_track" => 0,
            "issues_needs_attention" => 0,
            "issues_at_risk" => 0,
            "start_date" => epic3.start_date,
            "end_date" => epic3.end_date
          }, {
            "epic_state_id" => 2,
            "id" => epic3.id,
            "iid" => epic3.iid,
            "issues_count" => 1,
            "issues_state_id" => 1,
            "issues_weight_sum" => 0,
            "parent_id" => epic2.id,
            "issues_on_track" => 0,
            "issues_needs_attention" => 0,
            "issues_at_risk" => 1,
            "start_date" => epic3.start_date,
            "end_date" => epic3.end_date
          }]

          expect(result).to match_array(expected)
        end
      end
    end
  end

  it_behaves_like 'versioned description'

  describe '#usage_ping_record_epic_creation' do
    it 'records epic creation after saving' do
      expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_created_action).with(author: user, namespace: group)

      create(:epic, author_id: user.id, group: group)
    end
  end

  context 'with coloured epics' do
    using RSpec::Parameterized::TableSyntax

    where(:epic_color, :expected_text_color) do
      ::EE::Epic::DEFAULT_COLOR | ::Gitlab::Color.of('#FFFFFF')
      ::Gitlab::Color.of('#FFFFFF') | ::Gitlab::Color.of('#1F1E24')
      ::Gitlab::Color.of('#000000') | ::Gitlab::Color.of('#FFFFFF')
    end

    with_them do
      it 'returns correct text color' do
        epic = build(:epic, color: epic_color)

        expect(epic.text_color).to be_color(expected_text_color)
      end
    end
  end

  describe '.epics_readable_by_user' do
    let_it_be(:visible_epic) { create(:epic) }
    let_it_be(:confidential_epic) { create(:epic, :confidential) }
    let(:epics) { [visible_epic] }

    subject { described_class.epics_readable_by_user(epics, user) }

    before do
      stub_licensed_features(epics: true)
    end

    context 'with an admin when admin mode is enabled', :enable_admin_mode do
      let(:user) { build(:user, admin: true) }

      it { expect(subject).to match_array(epics) }
    end

    context 'with an admin when admin mode is disabled' do
      let(:user) { build(:user, admin: true) }

      it 'returns the epics readable by the admin' do
        expect(visible_epic).to receive(:readable_by?).with(user).and_return(true)

        expect(subject).to match_array(epics)
      end

      it 'returns no epics when not given access' do
        allow(visible_epic).to receive(:readable_by?).with(user).and_return(false)

        expect(subject).to be_empty
      end
    end

    context 'with a regular user' do
      let(:user) { build(:user) }

      it 'returns the epics readable by the user' do
        expect(visible_epic).to receive(:readable_by?).with(user).and_return(true)

        expect(subject).to match_array(epics)
      end

      it 'returns an empty array when no epics are readable' do
        expect(visible_epic).to receive(:readable_by?).with(user).and_return(false)

        expect(subject).to be_empty
      end
    end

    context 'without a regular user' do
      let(:user) { nil }
      let(:epics) { [confidential_epic, visible_epic] }

      it 'returns epics that are publicly visible' do
        expect(subject).to contain_exactly(visible_epic)
      end
    end

    it 'avoids N+1 queries when authorizing a list of epics', :request_store do
      user = create(:user)
      group = create(:group, :private, maintainers: user)
      epic = create(:epic, group: group)
      control = ActiveRecord::QueryRecorder.new { described_class.epics_readable_by_user([epic], user) }

      new_group1 = create(:group, :public)
      new_group3 = create(:group, :public)
      new_group2 = create(:group, :private, parent: group)

      new_epic1 = create(:epic, group: new_group1)
      new_epic2 = create(:epic, group: new_group2)
      new_epic3 = create(:epic, group: new_group3)

      expect { described_class.epics_readable_by_user([epic, new_epic1, new_epic2, new_epic3], user) }
        .not_to exceed_query_limit(control).with_threshold(4)
      # Permission checks perform N+1 queries.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/353915 for more info.
    end

    context 'with group hierarchy' do
      let_it_be(:user) { create(:user) }
      let_it_be(:ancestor) { create(:group, :private) }
      let_it_be(:base_group) { create(:group, :private, parent: ancestor) }
      let_it_be(:subgroup) { create(:group, :private, parent: base_group) }

      let_it_be(:epic1) { create(:epic, group: ancestor) }
      let_it_be(:epic2) { create(:epic, group: base_group) }
      let_it_be(:epic3) { create(:epic, group: subgroup) }

      let_it_be(:epics) { [epic1, epic2, epic3] }

      context 'when user is not a member' do
        it 'returns no epic' do
          expect(described_class.epics_readable_by_user(epics, user)).to be_empty
        end
      end

      context 'when user is a reporter in the ancestor group' do
        before_all do
          ancestor.add_reporter(user)
        end

        it 'returns epics from all groups' do
          expect(described_class.epics_readable_by_user(epics, user)).to match_array(epics)
        end
      end

      context 'when user is a reporter in the base group' do
        before_all do
          base_group.add_reporter(user)
        end

        it 'returns epics in main group and its descendants' do
          expect(described_class.epics_readable_by_user(epics, user)).to contain_exactly(epic2, epic3)
        end
      end

      context 'when user is a reporter in the subgroup' do
        before_all do
          subgroup.add_reporter(user)
        end

        it 'returns epics in subgroup' do
          expect(described_class.epics_readable_by_user(epics, user)).to contain_exactly(epic3)
        end
      end
    end
  end

  describe '#related_epics' do
    let_it_be_with_reload(:epic) { create(:epic) }

    let_it_be(:user) { create(:user) }
    let_it_be(:public_epic) { create(:epic) }
    let_it_be(:confidential_epic) { create(:epic, :confidential) }
    let_it_be(:sub_epic) { create(:epic, group: create(:group, parent: epic.group)) }
    let_it_be(:private_epic) { create(:epic, group: create(:group, :private)) }

    before_all do
      epic.group.add_reporter(user)
    end

    context 'when epics feature is enabled' do
      before_all do
        [public_epic, confidential_epic, sub_epic, private_epic].each do |source_epic|
          create(:related_epic_link, source: source_epic, target: epic)
        end
      end

      before do
        stub_licensed_features(epics: true)
      end

      it 'returns readable related epics of the epic' do
        expect(epic.related_epics(user)).to contain_exactly(public_epic, sub_epic)
      end

      context 'when epic is a new record' do
        let(:new_epic) { build(:epic, group: group) }

        it { expect(new_epic.related_epics(user)).to be_empty }
      end
    end

    context 'when epics feature is disabled' do
      before do
        stub_licensed_features(epics: false)
      end

      it 'returns empty result' do
        expect(epic.related_epics(user)).to be_empty
      end
    end
  end

  describe 'ES related specs' do
    let_it_be(:epic, freeze: false) { create(:epic, group: group) }

    context 'when the group has use_elasticsearch? as true' do
      before do
        allow(group).to receive(:use_elasticsearch?).and_return(true)
      end

      it 'use_elasticsearch? is true' do
        expect(epic).to be_use_elasticsearch
      end

      context 'with elasticsearch enabled' do
        before do
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:elasticsearch_indexing?).and_return(true)
        end

        it 'calls ::Elastic::ProcessBookkeepingService.track! when the epic is updated' do
          expect(::Elastic::ProcessBookkeepingService).to receive(:track!).once do |*tracked_refs|
            expect(tracked_refs.count).to eq(1)
            expect(tracked_refs[0]).to be_a_kind_of(Epic)
            expect(tracked_refs[0].id).to eq(epic.id)
          end
          epic.update!(title: 'A new title')
        end
      end
    end

    context 'when the group has use_elasticsearch? as false' do
      before do
        allow(group).to receive(:use_elasticsearch?).and_return(false)
      end

      it 'use_elasticsearch? is false' do
        expect(epic).not_to be_use_elasticsearch
      end

      context 'with elasticsearch enabled' do
        before do
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:elasticsearch_indexing?).and_return(true)
        end

        it 'does not call ::Elastic::ProcessBookkeepingService.track! when the epic is updated' do
          expect(Elastic::ProcessBookkeepingService).not_to receive(:track!).with(*epic)

          epic.update!(title: 'A new title')
        end
      end
    end
  end

  describe '#epic_link_type' do
    let_it_be(:source_epic) { create(:epic, group: group) }
    let_it_be(:target_epic) { create(:epic, group: group) }
    let_it_be(:epic_link) { create(:related_epic_link, link_type: ::IssuableLink::TYPE_BLOCKS, source: source_epic, target: target_epic) }

    before_all do
      group.add_developer(user)
    end

    before do
      stub_licensed_features(epics: true, related_epics: true)
    end

    it 'returns nil if link_type attributes are not available' do
      expect(source_epic.epic_link_type).to be_nil
    end

    it 'returns link type value for sources' do
      related_epics = source_epic.related_epics(user)

      expect(related_epics.first.epic_link_type).to eq ::IssuableLink::TYPE_BLOCKS
    end

    it 'returns inverse link type value for targets' do
      related_epics = target_epic.related_epics(user)

      expect(related_epics.first.epic_link_type).to eq ::IssuableLink::TYPE_IS_BLOCKED_BY
    end
  end

  describe '#blocked_by_epics_for' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:blocking_epic_1) { create(:epic, group: group) }
    let_it_be(:other_group_blocking_epic) { create(:epic, group: create(:group, :private)) }
    let_it_be(:blocking_epic_2) { create(:epic, group: group) }
    let_it_be(:confidential_blocking_epic) { create(:epic, :confidential, group: group) }
    let_it_be(:related_epic) { create(:epic, group: group) }
    let_it_be(:closed_blocking_epic) { create(:epic, group: group, state: :closed) }

    before do
      stub_licensed_features(epics: true, related_epics: true)
    end

    before_all do
      create(:related_epic_link, source: blocking_epic_1, target: epic, link_type: IssuableLink::TYPE_BLOCKS)
      create(:related_epic_link, source: other_group_blocking_epic, target: epic, link_type: IssuableLink::TYPE_BLOCKS)
      create(:related_epic_link, source: blocking_epic_2, target: epic, link_type: IssuableLink::TYPE_BLOCKS)
      create(:related_epic_link, source: confidential_blocking_epic, target: epic, link_type: IssuableLink::TYPE_BLOCKS)
      create(:related_epic_link, source: epic, target: related_epic, link_type: IssuableLink::TYPE_RELATES_TO)
      create(:related_epic_link, source: closed_blocking_epic, target: epic, link_type: IssuableLink::TYPE_BLOCKS)
    end

    context 'when user can read epics' do
      it 'returns blocked epics' do
        group.add_developer(user)
        other_group_blocking_epic.group.add_developer(user)

        expect(epic.blocked_by_epics_for(user)).to match_array([blocking_epic_1, blocking_epic_2, other_group_blocking_epic, confidential_blocking_epic])
      end
    end

    context 'when user cannot read epic' do
      it 'returns empty array' do
        expect(epic.blocked_by_epics_for(user)).to be_empty
      end
    end

    context 'when user cannot read some spics' do
      it 'returns only epics that user can read' do
        guest = create(:user)
        group.add_guest(guest)

        expect(epic.blocked_by_epics_for(guest)).to match_array([blocking_epic_1, blocking_epic_2])
      end
    end
  end

  context 'order by closed_at' do
    let_it_be(:epic_a) { create(:epic, closed_at: 1.day.ago) }
    let_it_be(:epic_b) { create(:epic, closed_at: 5.days.ago) }
    let_it_be(:epic_c_nil) { create(:epic, closed_at: nil) }
    let_it_be(:epic_d) { create(:epic, closed_at: 3.days.ago) }

    describe '.order_closed_at_asc' do
      it 'orders on closed at' do
        expect(described_class.order_closed_at_asc.to_a).to eq([epic_b, epic_d, epic_a, epic_c_nil])
      end
    end

    describe '.order_closed_at_desc' do
      it 'orders on closed at' do
        expect(described_class.order_closed_at_desc.to_a).to eq([epic_a, epic_d, epic_b, epic_c_nil])
      end
    end
  end

  describe '#participants' do
    it_behaves_like 'issuable participants' do
      let_it_be(:issuable_parent) { create(:group, :public) }
      let_it_be_with_refind(:issuable) { create(:epic, group: issuable_parent) }

      let(:params) { { noteable: issuable } }
    end
  end

  describe '#total_issue_weight_and_count' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:issue) { create(:issue, weight: 20, project: project) }
    let_it_be(:issue2) { create(:issue, :closed, weight: 30, project: project) }
    let_it_be(:epic_issue) { create(:epic_issue, epic: epic, issue: issue) }
    let_it_be(:epic_issue2) { create(:epic_issue, epic: epic, issue: issue2) }

    let_it_be(:subepic) do
      create(
        :epic, parent: epic, group: group, total_opened_issue_weight: 10,
        total_closed_issue_weight: 20, total_opened_issue_count: 2,
        total_closed_issue_count: 3
      )
    end

    it 'returns hash of total issue weight and count including its subepics' do
      expect(epic.total_issue_weight_and_count).to eq(
        {
          total_opened_issue_weight: 30,
          total_closed_issue_weight: 50,
          total_opened_issue_count: 3,
          total_closed_issue_count: 4
        }
      )
    end
  end

  describe '#update_cached_metadata' do
    let_it_be(:parent_epic) { create(:epic, group: group) }

    it 'schedules cache update for parent epic when new subepic is created' do
      expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([parent_epic.id]).once

      create(:epic, parent: parent_epic, group: group)
    end

    it 'skips cache update if there is no epic parent' do
      expect(::Epics::UpdateCachedMetadataWorker).not_to receive(:perform_async)

      create(:epic, group: group)
    end

    context 'when adding existing subepic' do
      let_it_be_with_refind(:subepic) { create(:epic, group: group) }

      it 'schedules cache update for parent epic' do
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([parent_epic.id]).once

        subepic.work_item_parent_link = build(:parent_link, work_item_parent: parent_epic.work_item, work_item: subepic.work_item)
        subepic.update!(parent: parent_epic)
      end
    end

    context 'when epic is already assigned to other epic' do
      let_it_be(:old_parent) { create(:epic, group: group) }
      let_it_be_with_refind(:subepic) { create(:epic, group: group, parent: old_parent) }

      it 'schedules cache update for old parent and new parent epics' do
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([parent_epic.id]).once
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([old_parent.id]).once

        assign_epic_parent(subepic, parent_epic)
      end

      it 'schedules cache update for parent epic when removing subepic parent' do
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([old_parent.id]).once

        subepic.update!(parent: nil)
      end

      it 'schedules cache update for parent epic when subepic is destroyed' do
        expect(::Epics::UpdateCachedMetadataWorker).to receive(:perform_async).with([old_parent.id]).once

        subepic.destroy!
      end
    end
  end

  describe '#confidentiality_errors' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'returns correct message if epic has non-confidential issues' do
      create(:issue, project: project, epic: epic)

      expect(epic.confidentiality_errors)
        .to contain_exactly('Cannot make the epic confidential if it contains non-confidential issues')
    end

    it 'returns correct message if epic has non-confidential subepics' do
      create(:epic, parent: epic, group: group)

      expect(epic.confidentiality_errors)
        .to contain_exactly('Cannot make the epic confidential if it contains non-confidential child epics')
    end

    it 'is empty if epic has only confidential subepics' do
      create(:epic, :confidential, parent: epic, group: group)

      expect(epic.confidentiality_errors).to be_empty
    end

    it 'is empty if epic has only confidential issues' do
      create(:issue, :confidential, project: project, epic: epic)

      expect(epic.confidentiality_errors).to be_empty
    end
  end

  describe '#expire_etag_cache' do
    it 'expires etag cache when epic is changed' do
      epic = create(:epic, group: group)

      expect_next_instance_of(Gitlab::EtagCaching::Store) do |instance|
        expect(instance).to receive(:touch)
          .with(Gitlab::Routing.url_helpers.realtime_changes_group_epic_path(group, epic))
      end

      epic.update!(title: 'new title')
    end
  end

  context 'with exportable associations' do
    let_it_be(:group) { create(:group, :private) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:parent_epic) { create(:epic, group: group) }

    let_it_be_with_reload(:resource) { create(:epic, group: group, parent: parent_epic) }

    it_behaves_like 'an exportable', restricted_association: :parent
  end

  describe '#linked_items_count' do
    let_it_be(:epic1) { create(:epic, group: group) }
    let_it_be(:epic2) { create(:epic, group: group) }
    let_it_be(:epic3) { create(:epic, group: group) }
    let_it_be(:epic4) { build(:epic, group: group) }

    it 'returns number of epics linked to the epic' do
      create(:related_epic_link, source: epic1, target: epic2)
      create(:related_epic_link, source: epic1, target: epic3)

      expect(epic1.linked_items_count).to eq(2)
      expect(epic2.linked_items_count).to eq(1)
      expect(epic3.linked_items_count).to eq(1)
      expect(epic4.linked_items_count).to eq(0)
    end
  end

  describe '#sync_work_item_updated_at' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'updates the updated_at column on the work item' do
      expect(epic.work_item).to receive(:update_column).with(:updated_at, epic.updated_at).once

      epic.sync_work_item_updated_at
    end
  end

  describe '#icon_name' do
    let(:epic) { build(:epic, group: group) }

    it 'returns the epic icon name' do
      expect(epic.icon_name).to eq('work-item-epic')
    end
  end

  context 'with unified associations' do
    context 'with label_links' do
      let_it_be(:label1) { create(:group_label, group: group, title: 'epic-label-1') }
      let_it_be(:label2) { create(:group_label, group: group, title: 'epic-label-2') }
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:epic_label_link) { create(:label_link, label: label1, target: epic) }
      let_it_be(:epic_work_item_label_link) { create(:label_link, label: label2, target: work_item) }

      context 'when labels are fetched from the epic and epic work item' do
        it 'returns epic and epic work item label_links' do
          expect(epic.reload.label_links).to match_array([epic_label_link, epic_work_item_label_link])
          expect(work_item.reload.label_links).to match_array([epic_label_link, epic_work_item_label_link])
        end

        it 'returns epic and epic work item label_links queried by id' do
          expect(epic.reload.label_links.find(epic_label_link.id)).to eq(epic_label_link)
          expect(work_item.reload.label_links.find(epic_label_link.id)).to eq(epic_label_link)
        end
      end

      describe '#label_links.scope' do
        it 'returns work_item label_links when work_item exists' do
          expect(epic.label_links.scope).to eq(work_item.label_links)
        end
      end
    end

    context 'with labels' do
      let_it_be_with_reload(:label1) { create(:group_label, group: group, title: 'epic-label-1') }
      let_it_be_with_reload(:label2) { create(:group_label, group: group, title: 'epic-label-2') }
      let_it_be(:epic) { create(:epic, group: group, labels: [label1]) }
      let_it_be(:work_item) { epic.work_item }

      before_all do
        work_item.labels << label2
      end

      context 'when labels are fetched from the epic and epic work item' do
        it 'returns epic and epic work item labels' do
          expect(epic.reload.labels).to match_array([label1, label2])
          expect(work_item.reload.labels).to match_array([label1, label2])
        end

        it 'returns epic and epic work item labels queried by id' do
          expect(epic.reload.labels.find(label1.id)).to eq(label1)
          expect(work_item.reload.labels.find(label1.id)).to eq(label1)
        end
      end

      describe '#labels.find with block' do
        it 'uses block form of find' do
          result = epic.labels.find { |l| l.id == label1.id }
          expect(result).to eq(label1)
        end
      end

      describe '#labels.scope' do
        it 'returns work_item labels when work_item exists' do
          expect(epic.labels.scope).to eq(work_item.labels)
        end
      end

      describe '#labels.<<' do
        it 'delegates to work_item.labels when work_item exists' do
          label3 = create(:group_label, group: group, title: 'epic-label-3')

          epic.labels << label3

          expect(work_item.reload.labels).to include(label3)
        end
      end

      describe '#label_ids' do
        it 'returns work_item label_ids when work_item exists' do
          expect(epic.reload.label_ids).to match_array(work_item.reload.label_ids)
        end
      end
    end

    context 'with award_emoji' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:emoji_1) { create(:award_emoji, :upvote, awardable: work_item) }
      let_it_be(:emoji_2) { create(:award_emoji, :downvote, awardable: work_item) }

      describe '#award_emoji' do
        it 'returns work_item award_emoji' do
          expect(epic.award_emoji).to match_array(work_item.award_emoji)
        end
      end

      describe '.awarded' do
        it 'finds epics where work item has emoji from user' do
          user = emoji_1.user

          expect(described_class.awarded(user, name: AwardEmoji::UPVOTE_NAME)).to include(epic)
          expect(described_class.awarded(user, name: AwardEmoji::DOWNVOTE_NAME)).not_to include(epic)
        end
      end

      describe '.not_awarded' do
        it 'excludes epics where work item has emoji from user' do
          user = emoji_1.user

          expect(described_class.not_awarded(user, name: AwardEmoji::UPVOTE_NAME)).not_to include(epic)
          expect(described_class.not_awarded(user, name: AwardEmoji::DOWNVOTE_NAME)).to include(epic)
        end
      end

      context 'for order_upvotes' do
        let_it_be(:epic_2) { create(:epic, group: group) }

        describe '.order_upvotes_desc' do
          it 'orders by work item upvotes descending' do
            expect(described_class.where(id: [epic.id, epic_2.id]).order_upvotes_desc).to eq([epic, epic_2])
          end
        end

        describe '.order_upvotes_asc' do
          it 'orders by work item upvotes ascending' do
            expect(described_class.where(id: [epic.id, epic_2.id]).order_upvotes_asc).to eq([epic_2, epic])
          end
        end

        describe '.order_downvotes_desc' do
          it 'orders by work item downvotes descending' do
            expect(described_class.where(id: [epic.id, epic_2.id]).order_downvotes_desc).to eq([epic, epic_2])
          end
        end
      end
    end

    context 'when work_item is nil' do
      let(:epic_without_work_item) do
        create(:epic, group: group).tap do |e|
          allow(e).to receive(:work_item).and_return(nil)
        end
      end

      describe '#award_emoji' do
        it 'returns empty relation' do
          expect(epic_without_work_item.award_emoji).to be_empty
        end
      end

      describe '#label_links' do
        it 'returns empty relation' do
          expect(epic_without_work_item.label_links).to be_empty
        end

        describe '#scope' do
          it 'returns LabelLink.none when work_item is nil' do
            expect(epic_without_work_item.label_links.scope).to eq(LabelLink.none)
          end
        end

        describe '#find' do
          it 'falls back to super and raises RecordNotFound' do
            expect { epic_without_work_item.label_links.find(non_existing_record_id) }
              .to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end

      describe '#labels' do
        it 'returns empty relation' do
          expect(epic_without_work_item.labels).to be_empty
        end

        describe '#scope' do
          it 'returns Label.none when work_item is nil' do
            expect(epic_without_work_item.labels.scope).to eq(Label.none)
          end
        end

        describe '#<<' do
          it 'returns self without delegating to work_item' do
            label = create(:group_label, group: group)

            result = epic_without_work_item.labels << label

            expect(result).to be_a(ActiveRecord::Associations::CollectionProxy)
          end
        end

        describe '#find' do
          it 'falls back to super and raises RecordNotFound' do
            expect { epic_without_work_item.labels.find(non_existing_record_id) }
              .to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end

      describe '#label_ids' do
        it 'returns empty array' do
          expect(epic_without_work_item.label_ids).to eq([])
        end
      end
    end

    context 'with notes' do
      let_it_be_with_reload(:epic) { create(:epic, group: group) }
      let_it_be_with_reload(:work_item) { epic.work_item }
      let_it_be(:note1) { create(:note, noteable: epic, note: 'first note on epic') }
      let_it_be(:note2) { create(:note, noteable: epic, note: 'second note on epic') }
      let_it_be(:note3) { create(:note, noteable: work_item, note: 'first note on epic work item') }

      context 'when notes are fetched from the epic and epic work item' do
        it 'returns epic and epic work item notes' do
          expect(epic.reload.notes).to match_array([note1, note2, note3])
          expect(work_item.reload.notes).to match_array([note1, note2, note3])

          expect(epic.reload.own_notes).to match_array([note1, note2])
          expect(work_item.reload.own_notes).to match_array([note3])
        end

        it 'returns epic and epic work item notes queried by id' do
          expect(epic.reload.notes.find(note1.id)).to eq(note1)
          expect(work_item.reload.notes.find(note1.id)).to eq(note1)
        end
      end
    end

    context 'with label resource events' do
      let_it_be(:label1) { create(:group_label, group: group, title: 'epic-label-1') }
      let_it_be(:label2) { create(:group_label, group: group, title: 'epic-label-2') }
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:label_resource_event1) { create(:resource_label_event, epic: epic, label: label1) }
      let_it_be(:label_resource_event2) { create(:resource_label_event, issue: work_item, label: label2) }

      context 'when label resource events are fetched from the epic and epic work item' do
        it 'returns epic and epic work item label events' do
          expect(epic.reload.resource_label_events).to match_array([label_resource_event1, label_resource_event2])
          expect(work_item.reload.resource_label_events).to match_array([label_resource_event1, label_resource_event2])

          expect(epic.reload.own_resource_label_events).to match_array([label_resource_event1])
          expect(work_item.reload.own_resource_label_events).to match_array([label_resource_event2])
        end

        it 'returns epic and epic work item label events queried by id' do
          expect(epic.reload.resource_label_events.find(label_resource_event1.id)).to eq(label_resource_event1)
          expect(work_item.reload.resource_label_events.find(label_resource_event1.id)).to eq(label_resource_event1)
        end
      end
    end

    context 'with state resource events' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:state_resource_event1) { create(:resource_state_event, epic: epic, state: :closed) }
      let_it_be(:state_resource_event2) { create(:resource_state_event, issue: work_item, state: :opened) }

      context 'when state resource events are fetched from the epic and epic work item' do
        it 'returns epic and epic work item state events' do
          expect(epic.reload.resource_state_events).to match_array([state_resource_event1, state_resource_event2])
          expect(work_item.reload.resource_state_events).to match_array([state_resource_event1, state_resource_event2])

          expect(epic.reload.own_resource_state_events).to match_array([state_resource_event1])
          expect(work_item.reload.own_resource_state_events).to match_array([state_resource_event2])
        end

        it 'returns epic and epic work item state events queried by id' do
          expect(epic.reload.resource_state_events.find(state_resource_event1.id)).to eq(state_resource_event1)
          expect(work_item.reload.resource_state_events.find(state_resource_event1.id)).to eq(state_resource_event1)
        end
      end
    end

    context 'with description versions' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:version1) { create(:description_version, epic: epic) }
      let_it_be(:version2) { create(:description_version, issue: work_item) }

      context 'when notes are fetched from the epic and epic work item' do
        it 'returns epic and epic work item notes' do
          expect(epic.reload.description_versions).to match_array([version1, version2])
          expect(work_item.reload.description_versions).to match_array([version1, version2])

          expect(epic.reload.own_description_versions).to match_array([version1])
          expect(work_item.reload.own_description_versions).to match_array([version2])
        end

        it 'returns epic and epic work item notes queried by id' do
          expect(epic.reload.description_versions.find(version1.id)).to eq(version1)
          expect(work_item.reload.description_versions.find(version1.id)).to eq(version1)
        end
      end
    end

    context 'with events' do
      let_it_be(:epic) { create(:epic, group: group) }
      let_it_be(:work_item) { epic.work_item }
      let_it_be(:epic_event) { create(:event, :created, group: group, project: nil, target: epic) }

      let_it_be(:epic_work_item_event1) do
        create(:event, :closed, group: group, project: nil, target_id: work_item.id, target_type: 'WorkItem')
      end

      let_it_be(:epic_work_item_event2) do
        create(:event, :reopened, group: group, project: nil, target_id: work_item.id, target_type: 'Issue')
      end

      context 'when events are fetched from the epic and epic work item' do
        it 'returns epic and epic work item events' do
          expect(epic.reload.events).to match_array([epic_event, epic_work_item_event1, epic_work_item_event2])
          expect(work_item.reload.events).to match_array([epic_event, epic_work_item_event1, epic_work_item_event2])

          expect(epic.reload.own_events).to match_array([epic_event])
          expect(work_item.reload.own_events).to match_array([epic_work_item_event1, epic_work_item_event2])
        end
      end
    end
  end

  context 'with subscriptions' do
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:work_item) { epic.work_item }
    let_it_be(:work_item_subscription) { create(:subscription, user: user, subscribable: work_item, subscribed: true) }

    context 'when subscriptions are read from the epic and the epic work item' do
      it 'returns subscriptions from both' do
        expect(epic.reload.subscriptions).to contain_exactly(work_item_subscription)
        expect(work_item.reload.subscriptions).to contain_exactly(work_item_subscription)
      end
    end
  end

  describe '#elastic_reference' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'returns the string representation for the elasticsearch' do
      expect(epic.elastic_reference).to eq("WorkItem|#{epic.issue_id}|#{epic.es_parent}")
    end
  end

  describe '#es_parent' do
    let_it_be(:epic) { create(:epic, group: group) }

    it 'returns to correct routing id' do
      expect(epic.es_parent).to eq("group_#{group.root_ancestor.id}")
    end
  end
end
