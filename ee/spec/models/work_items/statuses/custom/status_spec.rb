# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Status, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:group_2) { create(:group) }

  subject(:custom_status) { build_stubbed(:work_item_custom_status) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:created_by) }
    it { is_expected.to belong_to(:updated_by) }
    it { is_expected.to have_many(:lifecycle_statuses) }
    it { is_expected.to have_many(:lifecycles).through(:lifecycle_statuses) }
  end

  describe 'scopes' do
    describe '.in_namespace' do
      let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: group) }
      let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: group) }

      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_open_status) { create(:work_item_custom_status, :open, namespace: other_group) }

      it 'returns statuses for a specific namespace' do
        expect(described_class.in_namespace(group)).to contain_exactly(open_status, closed_status)
      end
    end

    describe '.ordered_for_lifecycle' do
      let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: group) }
      let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: group) }
      let_it_be(:duplicate_status) { create(:work_item_custom_status, :duplicate, namespace: group) }
      let_it_be(:in_review_status) do
        create(:work_item_custom_status, category: :in_progress, name: 'In review', namespace: group)
      end

      let_it_be(:in_dev_status) do
        create(:work_item_custom_status, category: :in_progress, name: 'In dev', namespace: group)
      end

      let_it_be(:custom_lifecycle) do
        create(:work_item_custom_lifecycle,
          namespace: group,
          default_open_status: open_status,
          default_closed_status: closed_status,
          default_duplicate_status: duplicate_status
        )
      end

      before do
        create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: in_review_status, position: 2)
        create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: in_dev_status, position: 1)
      end

      it 'returns statuses ordered by category, position, and id for a specific lifecycle' do
        ordered_statuses = described_class.ordered_for_lifecycle(custom_lifecycle.id)

        expect(ordered_statuses.map(&:name)).to eq([
          open_status.name,
          in_dev_status.name,
          in_review_status.name,
          closed_status.name,
          duplicate_status.name
        ])

        expect(ordered_statuses.map(&:category)).to eq(%w[to_do in_progress in_progress done canceled])
      end
    end

    describe '.converted_from_system_defined' do
      let_it_be(:converted_status) do
        create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: 1)
      end

      let_it_be(:non_converted_status) do
        create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: nil)
      end

      it 'returns statuses that were converted from a system defined status' do
        expect(described_class.converted_from_system_defined).to contain_exactly(converted_status)
      end
    end
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(32) }
    it { is_expected.to validate_presence_of(:color) }
    it { is_expected.to validate_length_of(:color).is_at_most(7) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_length_of(:description).is_at_most(128).allow_blank }

    context 'with name uniqueness' do
      it 'validates uniqueness with a custom validator' do
        create(:work_item_custom_status, name: "Test Status", namespace: group)

        duplicate_status = build(:work_item_custom_status, name: " test status ", namespace: group)
        expect(duplicate_status).to be_invalid
        expect(duplicate_status.errors.full_messages).to include('Name has already been taken')

        new_status = build(:work_item_custom_status, name: "Test Status", namespace: create(:group))
        expect(new_status).to be_valid
      end
    end

    context 'with name character restrictions' do
      context 'with valid names' do
        where(:valid_name, :description) do
          [
            ['In Progress 123', 'has alphanumeric characters'],
            ['In development', 'has spaces'],
            ['Ready for Review!', 'has punctuation'],
            ['Done ✅', 'has emojis'],
            ["Won't do", 'has quotes in middle'],
            ['Phase-1', 'has dashes']
          ]
        end

        with_them do
          it "is valid when name #{description}" do
            custom_status.name = valid_name

            expect(custom_status).to be_valid
          end
        end
      end

      context 'with invalid names' do
        let_it_be(:error_message) do
          'cannot start or end with quotes, backticks, or contain control characters'
        end

        where(:invalid_name, :description) do
          [
            ['"In Progress', 'starts with double quote'],
            ['In Progress"', 'ends with double quote'],
            ["'In Progress", 'starts with single quote'],
            ["In Progress'", 'ends with single quote'],
            ['`In Progress', 'starts with backtick'],
            ['In Progress`', 'ends with backtick'],
            ["In\nProgress", 'contains control character']
          ]
        end

        with_them do
          it "is invalid when name #{description}" do
            custom_status.name = invalid_name

            expect(custom_status).to be_invalid
            expect(custom_status.errors[:name]).to include(error_message)
          end
        end
      end
    end

    describe 'status per namespace limit validations' do
      let_it_be_with_reload(:existing_status) { create(:work_item_custom_status, namespace: group) }

      before do
        stub_const('WorkItems::Statuses::Custom::Status::MAX_STATUSES_PER_NAMESPACE', 1)
      end

      it 'is invalid when exceeding maximum allowed statuses' do
        new_status = build(:work_item_custom_status, namespace: group)

        expect(new_status).not_to be_valid
        expect(new_status.errors[:namespace]).to include('can only have a maximum of 1 statuses.')
      end

      it 'allows updating attributes of an existing status when limit is reached' do
        existing_status.name = 'Updated Name'

        expect(existing_status).to be_valid
      end
    end

    context 'with invalid color' do
      it 'is invalid' do
        custom_status.color = '000000'
        expect(custom_status).to be_invalid
        expect(custom_status.errors[:color]).to include('must be a valid color code')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:category).with_values(described_class::CATEGORIES) }
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
    it { is_expected.to include(WorkItems::Statuses::Status) }
  end

  describe '.find_by_namespace_and_name' do
    let_it_be(:custom_status) { create(:work_item_custom_status, name: 'In progress', namespace: group) }

    it 'finds a custom status by namespace and name' do
      expect(described_class.find_by_namespace_and_name(group, 'In progress')).to eq(custom_status)
    end

    it 'ignores leading and trailing whitespace and matches case insensitively' do
      expect(described_class.find_by_namespace_and_name(group, ' in Progress ')).to eq(custom_status)
    end

    it 'returns nil when name does not match' do
      expect(described_class.find_by_namespace_and_name(group, 'other status')).to be_nil
    end
  end

  describe '.find_by_namespaces_with_partial_name' do
    let_it_be(:to_do_status_1) { create(:work_item_custom_status, :to_do, name: 'To Do', namespace: group) }
    let_it_be(:to_do_status_2) { create(:work_item_custom_status, :to_do, name: 'To Do', namespace: group_2) }
    let_it_be(:done_status_1) { create(:work_item_custom_status, :done, name: 'Done', namespace: group) }
    let_it_be(:done_status_2) { create(:work_item_custom_status, :done, name: 'Done', namespace: group_2) }

    it 'returns unique statuses from multiple namespaces' do
      result = described_class.find_by_namespaces_with_partial_name([group.id, group_2.id])

      expect(result).to contain_exactly(to_do_status_2, done_status_2)
    end

    context 'when filtering by name' do
      context 'when statuses exist' do
        it 'returns statuses that exactly match the provided name' do
          result = described_class.find_by_namespaces_with_partial_name([group.id, group_2.id], 'To do')

          expect(result).to contain_exactly(to_do_status_2)
        end

        it 'returns statuses that partially match the provided name' do
          result = described_class.find_by_namespaces_with_partial_name([group.id, group_2.id], 'do')

          expect(result).to contain_exactly(to_do_status_2, done_status_2)
        end

        it 'handles case insensitivity' do
          result = described_class.find_by_namespaces_with_partial_name([group.id, group_2.id], 'to do')

          expect(result).to contain_exactly(to_do_status_2)
        end

        it 'handles whitespace' do
          result = described_class.find_by_namespaces_with_partial_name([group.id, group_2.id], ' To Do ')

          expect(result).to contain_exactly(to_do_status_2)
        end
      end

      context 'when statuses do not exist' do
        it 'returns an empty collection' do
          result = described_class.find_by_namespaces_with_partial_name([group.id, group_2.id], 'non-existent')

          expect(result).to be_empty
        end
      end
    end
  end

  describe '.find_by_converted_status' do
    let_it_be(:converted_status) do
      create(:work_item_custom_status, namespace: group, converted_from_system_defined_status_identifier: 1)
    end

    let_it_be(:other_custom_status) { create(:work_item_custom_status, :without_conversion_mapping, namespace: group) }

    let(:system_defined_status) { build(:work_item_system_defined_status, :to_do) }

    it 'finds status by the provided system-defined status' do
      result = described_class.find_by_converted_status(system_defined_status)

      expect(result).to eq(converted_status)
    end
  end

  describe '.find_by_name_across_namespaces' do
    let_it_be(:to_do_status_1) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group) }
    let_it_be(:to_do_status_2) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group_2) }
    let_it_be(:done_status_1) { create(:work_item_custom_status, :done, name: 'Done', namespace: group) }

    let(:status_name) { 'To do' }
    let(:namespace_ids) { [group.id, group_2.id] }

    subject(:result) { described_class.find_by_name_across_namespaces(status_name, namespace_ids) }

    it 'returns statuses that exactly match the name' do
      expect(result).to contain_exactly(to_do_status_1, to_do_status_2)
    end

    context 'when status name is lower case' do
      let(:status_name) { 'to do' }

      it 'matches case insensitive' do
        expect(result).to contain_exactly(to_do_status_1, to_do_status_2)
      end
    end

    context 'with invalid name' do
      let(:status_name) { 'Invalid' }

      it 'returns an empty collection' do
        expect(result).to be_empty
      end
    end
  end

  describe '#icon_name' do
    it 'returns the icon name based on the category' do
      expect(custom_status.icon_name).to eq('status-waiting')
    end
  end

  describe '#position' do
    it 'returns 0 as the default position' do
      expect(custom_status.position).to eq(0)
    end
  end

  describe '#in_use_in_lifecycle?' do
    let_it_be(:custom_status) { create(:work_item_custom_status, :to_do, namespace: group) }

    let_it_be(:lifecycle) do
      create(:work_item_custom_lifecycle, namespace: group, default_open_status: custom_status)
    end

    before do
      stub_licensed_features(work_item_status: true)

      create(
        :work_item_type_custom_lifecycle,
        namespace: group, work_item_type: build(:work_item_system_defined_type, :issue), lifecycle: lifecycle
      )
    end

    context 'when custom status is in use' do
      before do
        create(:work_item, namespace: group, custom_status_id: custom_status.id)
      end

      it 'returns true' do
        expect(custom_status.in_use_in_lifecycle?(lifecycle)).to be true
      end
    end

    context 'when custom status is used using system defined mapping' do
      let(:work_item) { create(:work_item, namespace: group) }

      before do
        # Skip validations since we are simulating an old record
        # when the namespace still used the system defined lifecycle
        build(
          :work_item_current_status,
          system_defined_status_id: custom_status.converted_from_system_defined_status_identifier,
          work_item: work_item,
          namespace: group
        ).save!(validate: false)
      end

      it 'returns true' do
        expect(custom_status.in_use_in_lifecycle?(lifecycle)).to be true
      end
    end

    context 'when custom status is used in another lifecycle' do
      let_it_be(:lifecycle_2) do
        create(:work_item_custom_lifecycle, namespace: group, default_open_status: custom_status)
      end

      before do
        create(
          :work_item_type_custom_lifecycle,
          namespace: group, work_item_type: build(:work_item_system_defined_type, :task), lifecycle: lifecycle_2
        )

        create(:work_item, :task, namespace: group, custom_status_id: custom_status.id)
      end

      it 'returns false' do
        expect(custom_status.in_use_in_lifecycle?(lifecycle)).to be_falsy
      end
    end

    context 'when custom status is not in use' do
      it 'returns false' do
        expect(custom_status.in_use_in_lifecycle?(lifecycle)).to be_falsy
      end
    end
  end

  describe '#can_be_deleted_from_namespace?' do
    let_it_be(:issue_work_item_type) { build(:work_item_system_defined_type, :issue) }

    let_it_be(:to_do_status) { create(:work_item_custom_status, :to_do, namespace: group) }

    let_it_be_with_reload(:lifecycle) do
      create(:work_item_custom_lifecycle, namespace: group, default_open_status: to_do_status)
    end

    subject { to_do_status.can_be_deleted_from_namespace?(lifecycle) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'when status is not used outside of lifecycle' do
      it { is_expected.to be true }
    end

    context 'when status is also used in another lifecycle' do
      let_it_be(:lifecycle_2) do
        create(:work_item_custom_lifecycle, namespace: group, default_open_status: to_do_status)
      end

      it { is_expected.to be false }
    end

    context 'when status is in use by work items' do
      let_it_be(:work_item) do
        create(:work_item, :issue, custom_status_id: to_do_status.id, namespace: group)
      end

      before do
        create(
          :work_item_type_custom_lifecycle,
          namespace: group, work_item_type: build(:work_item_system_defined_type, :issue), lifecycle: lifecycle
        )
      end

      it { is_expected.to be false }
    end

    context 'when status is used in a mapping' do
      let_it_be(:to_do_status_2) { create(:work_item_custom_status, :to_do, namespace: group) }

      let_it_be(:custom_status_mapping) do
        create(:work_item_custom_status_mapping,
          namespace: group,
          work_item_type: issue_work_item_type,
          old_status: to_do_status,
          new_status: to_do_status_2
        )
      end

      it { is_expected.to be false }
    end
  end
end
