# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Mapping, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:namespace) { create(:namespace) }
  let_it_be_with_refind(:other_namespace) { create(:namespace) }
  let_it_be_with_refind(:work_item_type) { build(:work_item_system_defined_type) }
  let_it_be_with_refind(:ticket_work_item_type) { build(:work_item_system_defined_type, :ticket) }
  let_it_be_with_refind(:old_status) { create(:work_item_custom_status, namespace: namespace) }
  let_it_be_with_refind(:new_status) { create(:work_item_custom_status, namespace: namespace) }
  let_it_be_with_refind(:other_old_status) { create(:work_item_custom_status, namespace: other_namespace) }
  let_it_be_with_refind(:other_new_status) { create(:work_item_custom_status, namespace: other_namespace) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:old_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:new_status).class_name('WorkItems::Statuses::Custom::Status') }
  end

  describe 'validations' do
    subject { build(:work_item_custom_status_mapping) }

    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:work_item_type_id) }
    it { is_expected.to validate_presence_of(:old_status) }
    it { is_expected.to validate_presence_of(:new_status) }

    it_behaves_like 'validates work item type ID'

    describe '#old_status_role' do
      it 'allows nil values for regular custom statuses' do
        mapping = build(:work_item_custom_status_mapping, old_status_role: nil)
        expect(mapping).to be_valid
      end

      it 'allows valid enum values' do
        %w[open closed duplicate].each do |role|
          mapping = build(:work_item_custom_status_mapping, old_status_role: role)
          expect(mapping).to be_valid
        end
      end
    end

    it 'is invalid when old_status and new_status are the same' do
      mapping = build(:work_item_custom_status_mapping,
        namespace: namespace,
        work_item_type: work_item_type,
        old_status: old_status,
        new_status: old_status
      )

      expect(mapping).not_to be_valid
      expect(mapping.errors[:new_status]).to include('cannot be the same as old status')
    end

    context 'when validating date range' do
      it 'is valid when valid_from is before valid_until' do
        mapping = build(:work_item_custom_status_mapping,
          valid_from: 1.day.ago,
          valid_until: 1.day.from_now
        )

        expect(mapping).to be_valid
      end

      it 'is valid when only valid_from is present' do
        mapping = build(:work_item_custom_status_mapping,
          valid_from: 1.day.ago,
          valid_until: nil
        )

        expect(mapping).to be_valid
      end

      it 'is valid when only valid_until is present' do
        mapping = build(:work_item_custom_status_mapping,
          valid_from: nil,
          valid_until: 1.day.from_now
        )

        expect(mapping).to be_valid
      end

      it 'is valid when both dates are nil' do
        mapping = build(:work_item_custom_status_mapping,
          valid_from: nil,
          valid_until: nil
        )

        expect(mapping).to be_valid
      end

      it 'is invalid when valid_from is after valid_until' do
        mapping = build(:work_item_custom_status_mapping,
          valid_from: 1.day.from_now,
          valid_until: 1.day.ago
        )

        expect(mapping).not_to be_valid
        expect(mapping.errors[:valid_until]).to include('must be after valid_from date')
      end

      it 'is invalid when valid_from equals valid_until' do
        same_date = Time.current
        mapping = build(:work_item_custom_status_mapping,
          valid_from: same_date,
          valid_until: same_date
        )

        expect(mapping).not_to be_valid
        expect(mapping.errors[:valid_until]).to include('must be after valid_from date')
      end
    end

    context 'when validating statuses namespace' do
      let(:expected_message) { 'statuses must belong to the same namespace as the mapping' }

      it 'is valid when both statuses belong to the same namespace as the mapping' do
        mapping = build(:work_item_custom_status_mapping,
          namespace: namespace,
          old_status: old_status,
          new_status: new_status
        )

        expect(mapping).to be_valid
      end

      it 'is invalid when old_status belongs to a different namespace' do
        mapping = build(:work_item_custom_status_mapping,
          namespace: namespace,
          old_status: other_old_status,
          new_status: new_status
        )

        expect(mapping).not_to be_valid
        expect(mapping.errors[:base]).to include(expected_message)
      end

      it 'is invalid when new_status belongs to a different namespace' do
        mapping = build(:work_item_custom_status_mapping,
          namespace: namespace,
          old_status: old_status,
          new_status: other_new_status
        )

        expect(mapping).not_to be_valid
        expect(mapping.errors[:base]).to include(expected_message)
      end

      it 'is invalid when both statuses belong to different namespaces than the mapping' do
        mapping = build(:work_item_custom_status_mapping,
          namespace: namespace,
          old_status: other_old_status,
          new_status: other_new_status
        )

        expect(mapping).not_to be_valid
        expect(mapping.errors[:base]).to include(expected_message)
      end
    end

    context 'when validating chained mappings' do
      let_it_be(:status_a) { create(:work_item_custom_status, namespace: namespace) }
      let_it_be(:status_b) { create(:work_item_custom_status, namespace: namespace) }
      let_it_be(:status_c) { create(:work_item_custom_status, namespace: namespace) }
      let_it_be(:status_d) { create(:work_item_custom_status, namespace: namespace) }

      it 'is valid when creating the first mapping' do
        mapping = build(:work_item_custom_status_mapping,
          namespace: namespace,
          work_item_type: work_item_type,
          old_status: status_a,
          new_status: status_b
        )

        expect(mapping).to be_valid
      end

      context 'when a mapping already exists' do
        let_it_be_with_reload(:existing_mapping) do
          create(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_a,
            new_status: status_b
          )
        end

        it 'allows updating an existing mapping' do
          existing_mapping.valid_from = 1.day.ago
          expect(existing_mapping).to be_valid
        end

        it 'is invalid when new_status is already mapped to another status' do
          # A -> B -> C is a chain
          chained_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_b,
            new_status: status_c
          )

          expect(chained_mapping).not_to be_valid
          expect(chained_mapping.errors[:old_status]).to include('is already the target of another mapping')
        end

        it 'is invalid when old_status is already the target of another mapping' do
          # C -> A -> B is a chain, where this mapping would be the first chain link
          chained_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_c,
            new_status: status_a
          )

          expect(chained_mapping).not_to be_valid
          expect(chained_mapping.errors[:new_status]).to include('is already mapped to another status')
        end
      end
    end

    context 'when validating overlapping date ranges' do
      let_it_be(:status_x) { create(:work_item_custom_status, namespace: namespace) }
      let_it_be(:status_y) { create(:work_item_custom_status, namespace: namespace) }
      let_it_be(:status_z) { create(:work_item_custom_status, namespace: namespace) }

      context 'with existing mapping' do
        let_it_be_with_reload(:existing_mapping) do
          create(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_x,
            new_status: status_y,
            valid_from: 5.days.ago,
            valid_until: 2.days.ago
          )
        end

        it 'is valid when creating non-overlapping sequential mappings' do
          sequential_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_x,
            new_status: status_z,
            valid_from: 2.days.ago,
            valid_until: nil
          )

          expect(sequential_mapping).to be_valid
          # Persist so we test that we exclude self in date range validation
          sequential_mapping.save!
          expect(sequential_mapping.reset).to be_valid
        end

        it 'is valid when mappings have gaps between them' do
          gap_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_x,
            new_status: status_z,
            valid_from: 1.day.ago,
            valid_until: nil
          )

          expect(gap_mapping).to be_valid
        end

        it 'is invalid when date ranges overlap' do
          overlapping_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_x,
            new_status: status_z,
            valid_from: 3.days.ago,
            valid_until: nil
          )

          expect(overlapping_mapping).not_to be_valid
          expect(overlapping_mapping.errors[:base]).to include('date range overlaps with existing mapping')
        end

        it 'is invalid when new mapping completely contains existing mapping' do
          containing_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_x,
            new_status: status_z,
            valid_from: 6.days.ago,
            valid_until: 1.day.ago
          )

          expect(containing_mapping).not_to be_valid
          expect(containing_mapping.errors[:base]).to include('date range overlaps with existing mapping')
        end

        it 'is invalid when existing mapping completely contains new mapping' do
          contained_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_x,
            new_status: status_z,
            valid_from: 4.days.ago,
            valid_until: 3.days.ago
          )

          expect(contained_mapping).not_to be_valid
          expect(contained_mapping.errors[:base]).to include('date range overlaps with existing mapping')
        end

        it 'is valid when mappings are for different old_status' do
          different_old_status_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: work_item_type,
            old_status: status_z,
            new_status: status_y,
            valid_from: 5.days.ago,
            valid_until: 2.days.ago
          )

          expect(different_old_status_mapping).to be_valid
        end

        it 'is valid when mappings are for different work_item_type' do
          different_type_mapping = build(:work_item_custom_status_mapping,
            namespace: namespace,
            work_item_type: ticket_work_item_type,
            old_status: status_x,
            new_status: status_y,
            valid_from: 5.days.ago,
            valid_until: 2.days.from_now
          )

          expect(different_type_mapping).to be_valid
        end

        it 'allows updating an existing mapping' do
          existing_mapping.valid_from = 3.days.ago
          expect(existing_mapping).to be_valid
        end
      end

      it 'is invalid when mappings have open-ended ranges that overlap' do
        create(:work_item_custom_status_mapping,
          namespace: namespace,
          work_item_type: work_item_type,
          old_status: status_x,
          new_status: status_y,
          valid_from: 3.days.ago,
          valid_until: nil
        )

        overlapping_open_mapping = build(:work_item_custom_status_mapping,
          namespace: namespace,
          work_item_type: work_item_type,
          old_status: status_x,
          new_status: status_z,
          valid_from: nil,
          valid_until: 1.day.ago
        )

        expect(overlapping_open_mapping).not_to be_valid
        expect(overlapping_open_mapping.errors[:base]).to include('date range overlaps with existing mapping')
      end
    end
  end

  describe 'scopes' do
    let_it_be(:mapping_in_namespace) do
      create(:work_item_custom_status_mapping,
        namespace: namespace,
        work_item_type: work_item_type,
        old_status: old_status,
        new_status: new_status
      )
    end

    let_it_be(:mapping_in_other_namespace) do
      create(:work_item_custom_status_mapping,
        namespace: other_namespace,
        work_item_type: work_item_type,
        old_status: create(:work_item_custom_status, namespace: other_namespace),
        new_status: create(:work_item_custom_status, namespace: other_namespace)
      )
    end

    describe '.with_namespace_id' do
      it 'returns mappings only for the specified namespace' do
        result = described_class.with_namespace_id(namespace.id)

        expect(result).to contain_exactly(mapping_in_namespace)
        expect(result).not_to include(mapping_in_other_namespace)
      end

      it 'returns empty collection when namespace_id has no mappings' do
        empty_namespace = create(:namespace)
        result = described_class.with_namespace_id(empty_namespace.id)

        expect(result).to be_empty
      end
    end

    describe '.originating_from_status' do
      it 'returns mappings originating from the specified status' do
        result = described_class.originating_from_status(
          namespace: namespace, status: old_status, work_item_type: work_item_type
        )

        expect(result).to contain_exactly(mapping_in_namespace)
      end

      it 'accepts raw work_item_type_id values' do
        result = described_class.originating_from_status(
          namespace: namespace, status: old_status, work_item_type: work_item_type.id
        )

        expect(result).to contain_exactly(mapping_in_namespace)
      end
    end
  end

  describe '#applicable_for?' do
    let(:mapping) { build(:work_item_custom_status_mapping) }
    let(:test_date) { Time.current }

    context 'when both valid_from and valid_until are nil' do
      it 'returns true for any date' do
        expect(mapping.applicable_for?(test_date)).to be true
        expect(mapping.applicable_for?(1.year.ago)).to be true
        expect(mapping.applicable_for?(1.year.from_now)).to be true
      end
    end

    context 'when only valid_from is set' do
      before do
        mapping.valid_from = 5.days.ago
      end

      it 'returns true for dates on or after valid_from' do
        expect(mapping.applicable_for?(5.days.ago)).to be true
        expect(mapping.applicable_for?(4.days.ago)).to be true
        expect(mapping.applicable_for?(test_date)).to be true
        expect(mapping.applicable_for?(1.day.from_now)).to be true
      end

      it 'returns false for dates before valid_from' do
        expect(mapping.applicable_for?(6.days.ago)).to be false
        expect(mapping.applicable_for?(1.week.ago)).to be false
      end
    end

    context 'when only valid_until is set' do
      before do
        mapping.valid_until = 2.days.from_now
      end

      it 'returns true for dates before valid_until' do
        expect(mapping.applicable_for?(1.week.ago)).to be true
        expect(mapping.applicable_for?(test_date)).to be true
        expect(mapping.applicable_for?(1.day.from_now)).to be true
      end

      it 'returns false for dates on or after valid_until' do
        expect(mapping.applicable_for?(2.days.from_now)).to be false
        expect(mapping.applicable_for?(3.days.from_now)).to be false
        expect(mapping.applicable_for?(1.week.from_now)).to be false
      end
    end

    context 'when both valid_from and valid_until are set' do
      before do
        mapping.valid_from = 5.days.ago
        mapping.valid_until = 2.days.from_now
      end

      it 'returns true for dates within the range (inclusive of valid_from, exclusive of valid_until)' do
        expect(mapping.applicable_for?(5.days.ago)).to be true
        expect(mapping.applicable_for?(3.days.ago)).to be true
        expect(mapping.applicable_for?(test_date)).to be true
        expect(mapping.applicable_for?(1.day.from_now)).to be true
      end

      it 'returns false for dates before valid_from' do
        expect(mapping.applicable_for?(6.days.ago)).to be false
        expect(mapping.applicable_for?(1.week.ago)).to be false
      end

      it 'returns false for dates on or after valid_until' do
        expect(mapping.applicable_for?(2.days.from_now)).to be false
        expect(mapping.applicable_for?(3.days.from_now)).to be false
        expect(mapping.applicable_for?(1.week.from_now)).to be false
      end
    end

    context 'with edge cases' do
      it 'handles exact boundary dates correctly' do
        mapping.valid_from = 1.day.ago
        mapping.valid_until = 1.day.from_now

        # valid_from is inclusive
        expect(mapping.applicable_for?(1.day.ago)).to be true
        # valid_until is exclusive
        expect(mapping.applicable_for?(1.day.from_now)).to be false
      end

      it 'handles same date for valid_from and test date' do
        exact_date = Time.current.beginning_of_day
        mapping.valid_from = exact_date
        mapping.valid_until = nil

        expect(mapping.applicable_for?(exact_date)).to be true
      end
    end
  end

  describe '#time_range' do
    let(:mapping) { build(:work_item_custom_status_mapping, valid_from: valid_from, valid_until: valid_until) }
    let(:from_time) { 5.days.ago }
    let(:until_time) { 2.days.ago }

    subject(:time_range) { mapping.time_range }

    where(:valid_from, :valid_until, :expected_type, :expected_begin, :expected_end) do
      ref(:from_time) | ref(:until_time) | Range     | ref(:from_time) | ref(:until_time)
      ref(:from_time) | nil              | Range     | ref(:from_time) | nil
      nil             | ref(:until_time) | Range     | nil             | ref(:until_time)
      nil             | nil              | NilClass  | nil             | nil
    end

    with_them do
      it 'returns the expected range type and boundaries' do
        if expected_type == NilClass
          is_expected.to be_nil
        else
          is_expected.to be_a(Range)
          expect(time_range.begin).to eq(expected_begin)
          expect(time_range.end).to eq(expected_end)
        end
      end
    end
  end

  describe '#time_constrained?' do
    let(:mapping) { build(:work_item_custom_status_mapping, valid_from: valid_from, valid_until: valid_until) }

    subject { mapping.time_constrained? }

    where(:valid_from, :valid_until, :expected_result) do
      nil         | nil              | false
      3.days.ago  | nil              | true
      nil         | 1.day.from_now   | true
      5.days.ago  | 2.days.ago       | true
      1.year.ago  | nil              | true
      nil         | 1.year.from_now  | true
    end

    with_them do
      it { is_expected.to eq(expected_result) }
    end
  end

  describe 'foreign key constraints' do
    let!(:mapping) do
      create(:work_item_custom_status_mapping,
        old_status: old_status,
        new_status: new_status,
        namespace: namespace,
        work_item_type: work_item_type
      )
    end

    context 'when old_status is deleted' do
      it 'prevents deletion due to restrict constraint' do
        expect { old_status.destroy! }.to raise_error(ActiveRecord::StatementInvalid)
        expect(described_class.exists?(mapping.id)).to be true
      end
    end

    context 'when new_status is deleted' do
      it 'cascades deletion of mapping' do
        expect { new_status.destroy! }.not_to raise_error
        expect(described_class.exists?(mapping.id)).to be false
      end
    end

    context 'when namespace is deleted' do
      it 'cascades deletion of mapping' do
        expect { namespace.destroy! }.not_to raise_error
        expect(described_class.exists?(mapping.id)).to be false
      end
    end
  end
end
