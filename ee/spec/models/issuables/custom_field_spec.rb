# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomField, feature_category: :team_planning do
  subject(:custom_field) { build(:custom_field) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:created_by) }
    it { is_expected.to belong_to(:updated_by) }
    it { is_expected.to have_many(:select_options) }
    it { is_expected.to have_many(:work_item_type_custom_fields) }

    it 'orders select_options by position' do
      custom_field.save!

      option_1 = create(:custom_field_select_option, custom_field: custom_field, position: 2)
      option_2 = create(:custom_field_select_option, custom_field: custom_field, position: 1)

      expect(custom_field.reload.select_options).to eq([option_2, option_1])
    end

    it 'orders work_item_types by name' do
      custom_field.save!

      issue_type = build(:work_item_system_defined_type, :issue)
      incident_type = build(:work_item_system_defined_type, :incident)
      task_type = build(:work_item_system_defined_type, :task)

      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: incident_type)
      create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

      expect(custom_field.reload.work_item_types).to contain_exactly(incident_type, issue_type, task_type)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id).case_insensitive }

    describe 'max select options' do
      let(:limit) { described_class::MAX_SELECT_OPTIONS }

      it 'is valid when select options are at the limit' do
        limit.times { custom_field.select_options.build(value: SecureRandom.hex) }

        expect(custom_field).to be_valid
      end

      it 'is not valid when select options exceed the limit' do
        (limit + 1).times { custom_field.select_options.build(value: SecureRandom.hex) }

        expect(custom_field).not_to be_valid
        expect(custom_field.errors[:select_options]).to include("exceeds the limit of #{limit}.")
      end
    end

    describe '#namespace_is_root_group' do
      subject(:custom_field) { build(:custom_field, namespace: namespace) }

      context 'when namespace is a root group' do
        let(:namespace) { build(:group) }

        it { is_expected.to be_valid }
      end

      context 'when namespace is a subgroup' do
        let(:namespace) { build(:group, parent: build(:group)) }

        it 'returns a validation error' do
          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:namespace]).to include('must be a root group.')
        end
      end

      context 'when namespace is a personal namespace' do
        let(:namespace) { build(:namespace) }

        it 'returns a validation error' do
          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:namespace]).to include('must be a root group.')
        end
      end
    end

    describe '#number_of_fields_per_namespace' do
      let_it_be(:group) { create(:group) }

      before_all do
        create(:custom_field, namespace: group)
      end

      before do
        stub_const("#{described_class}::MAX_FIELDS", 2)
      end

      subject(:custom_field) { build(:custom_field, namespace: group) }

      it { is_expected.to be_valid }

      context 'when group is over the limit' do
        before_all do
          create(:custom_field, namespace: group)
        end

        shared_examples 'an invalid record' do
          it 'returns a validation error' do
            expect(custom_field).not_to be_valid
            expect(custom_field.errors[:namespace]).to include('can only have a maximum of 2 custom fields.')
          end
        end

        it_behaves_like 'an invalid record'

        context 'when creating an archived field' do
          subject(:custom_field) { build(:custom_field, :archived, namespace: group) }

          it_behaves_like 'an invalid record'
        end
      end
    end

    describe '#number_of_active_fields_per_namespace' do
      let_it_be(:group) { create(:group) }

      before do
        stub_const("#{described_class}::MAX_ACTIVE_FIELDS", 2)
      end

      subject(:custom_field) { build(:custom_field, namespace: group) }

      context 'when group is not at the limit' do
        before_all do
          create(:custom_field, namespace: group)
          create(:custom_field, :archived, namespace: group)
        end

        it { is_expected.to be_valid }
      end

      context 'when group is over the limit' do
        before_all do
          create_list(:custom_field, 2, namespace: group)
          create(:custom_field, :archived, namespace: group)
        end

        it 'is valid for an archived field' do
          custom_field.archived_at = Time.current

          expect(custom_field).to be_valid
        end

        it 'is valid for an existing active field' do
          existing_field = described_class.active.first

          expect(existing_field).to be_valid
        end

        shared_examples 'an invalid record' do
          it 'returns a validation error' do
            expect(custom_field).not_to be_valid
            expect(custom_field.errors[:namespace]).to include('can only have a maximum of 2 active custom fields.')
          end
        end

        context 'with a new active field' do
          it_behaves_like 'an invalid record'
        end

        context 'when making an existing archived field active' do
          subject(:custom_field) { described_class.archived.first }

          before do
            custom_field.archived_at = nil
          end

          it_behaves_like 'an invalid record'
        end
      end
    end

    describe '#number_of_active_fields_per_namespace_per_type' do
      let_it_be(:group) { create(:group) }
      let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
      let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

      before_all do
        # Issue type under the limit
        create(:custom_field, namespace: group, work_item_types: [issue_type])

        # Custom field with issue type but from a different namespace
        create(:custom_field, namespace: create(:group), work_item_types: [issue_type])

        # Task type at the limit
        create_list(:custom_field, 2, namespace: group, work_item_types: [task_type])
      end

      before do
        stub_const("#{described_class}::MAX_ACTIVE_FIELDS_PER_TYPE", 2)
      end

      subject(:custom_field) { build(:custom_field, namespace: group, work_item_types: [issue_type]) }

      it 'is valid when below the limit' do
        expect(custom_field).to be_valid
      end

      it 'is not valid when type is already at the limit' do
        custom_field.work_item_types = [task_type]

        expect(custom_field).not_to be_valid
        expect(custom_field.errors[:base]).to include(
          "Work item type #{task_type.name} can only have a maximum of 2 active custom fields."
        )
      end

      it 'is valid when field is inactive' do
        custom_field.work_item_types = [task_type]
        custom_field.archived_at = Time.current

        expect(custom_field).to be_valid
      end

      context 'when updating an existing record' do
        it 'is not valid when adding a type that is already at the limit' do
          custom_field.save!

          custom_field.work_item_types = [issue_type, task_type]

          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:base]).to include(
            "Work item type #{task_type.name} can only have a maximum of 2 active custom fields."
          )
        end
      end

      context 'when provider cannot resolve a type ID' do
        it 'skips unresolved types and does not add limit errors for them' do
          custom_field.work_item_types = [task_type]

          allow(WorkItems::TypesFramework::Provider).to receive(:new).and_wrap_original do |original, *args|
            provider = original.call(*args)
            allow(provider).to receive(:by_ids).and_return([])
            provider
          end

          custom_field.valid?

          expect(custom_field.errors[:base]).not_to include(
            a_string_matching(/can only have a maximum of/)
          )
        end
      end
    end

    describe '#selectable_field_type_with_select_options' do
      context 'when a select option exists' do
        before do
          custom_field.select_options.build(value: SecureRandom.hex)
        end

        it 'is valid when field_type is select' do
          custom_field.field_type = :single_select

          expect(custom_field).to be_valid
        end

        it 'is valid when field_type is multi_select' do
          custom_field.field_type = :multi_select

          expect(custom_field).to be_valid
        end

        it 'is invalid for non-select field types' do
          custom_field.field_type = :text

          expect(custom_field).not_to be_valid
          expect(custom_field.errors[:field_type]).to include('does not support select options.')
        end
      end

      context 'when there are no select options' do
        it 'is valid for non-select field types' do
          custom_field.field_type = :text

          expect(custom_field).to be_valid
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }

    let_it_be(:custom_field) { create(:custom_field, namespace: group, name: 'ZZZ') }
    let_it_be(:custom_field_2) { create(:custom_field, namespace: group, name: 'CCC') }
    let_it_be(:custom_field_archived) { create(:custom_field, :archived, namespace: group, name: 'AAA') }
    let_it_be(:other_custom_field) { create(:custom_field, namespace: create(:group), name: 'BBB') }

    describe '.of_namespace' do
      it 'returns custom fields of the given namespace' do
        expect(described_class.of_namespace(group)).to contain_exactly(
          custom_field, custom_field_2, custom_field_archived
        )
      end
    end

    describe '.active' do
      it 'returns active fields' do
        expect(described_class.active).to contain_exactly(
          custom_field, custom_field_2, other_custom_field
        )
      end
    end

    describe '.archived' do
      it 'returns archived fields' do
        expect(described_class.archived).to contain_exactly(
          custom_field_archived
        )
      end
    end

    describe '.ordered_by_status_and_name' do
      it 'returns active fields first, ordered by name' do
        expect(described_class.ordered_by_status_and_name).to eq([
          other_custom_field, custom_field_2, custom_field, custom_field_archived
        ])
      end
    end

    describe ".of_field_type" do
      let_it_be(:custom_field_number) { create(:custom_field, :number, namespace: group) }

      it "returns custom field of a given field type" do
        expect(described_class.of_field_type("number")).to contain_exactly(custom_field_number)
      end
    end

    describe '.find_by_case_insensitive_name' do
      it 'returns field matching with matching name case-insensitively' do
        expect(described_class.find_by_case_insensitive_name('cCc')).to eq(custom_field_2)
      end
    end

    describe 'work item type scopes' do
      let_it_be(:issue_type) { create(:work_item_system_defined_type, :issue) }
      let_it_be(:task_type) { create(:work_item_system_defined_type, :task) }

      before_all do
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: issue_type)
        create(:work_item_type_custom_field, custom_field: custom_field, work_item_type: task_type)

        create(:work_item_type_custom_field, custom_field: custom_field_2, work_item_type: issue_type)
      end

      describe '.without_any_work_item_types' do
        it 'returns custom fields that are not associated with any work item type' do
          expect(described_class.without_any_work_item_types).to contain_exactly(
            custom_field_archived, other_custom_field
          )
        end
      end

      describe '.with_work_item_types' do
        context 'with empty array' do
          it 'returns custom fields that are not associated with any work item type' do
            expect(described_class.with_work_item_types([])).to contain_exactly(
              custom_field_archived, other_custom_field
            )
          end
        end

        context 'with array of work item type IDs' do
          it 'returns custom fields that match any of the work item type IDs' do
            expect(
              described_class.with_work_item_types([issue_type.id, task_type.id])
            ).to contain_exactly(custom_field, custom_field_2)
          end
        end

        context 'with array of work item type objects' do
          it 'returns custom fields that match any of the work item types' do
            expect(described_class.with_work_item_types([issue_type, task_type])).to contain_exactly(
              custom_field, custom_field_2
            )
          end
        end
      end
    end
  end

  describe '#active?' do
    it 'returns true when archived_at is nil' do
      field = build(:custom_field, archived_at: nil)

      expect(field.active?).to be(true)
    end

    it 'returns false when archived_at is set' do
      field = build(:custom_field, archived_at: Time.current)

      expect(field.active?).to be(false)
    end
  end

  describe '#field_type_select?' do
    it 'returns true for single select types' do
      field = build(:custom_field, field_type: :single_select)

      expect(field.field_type_select?).to be(true)
    end

    it 'returns true for multi select types' do
      field = build(:custom_field, field_type: :multi_select)

      expect(field.field_type_select?).to be(true)
    end

    it 'returns false for other types' do
      field = build(:custom_field, field_type: :text)

      expect(field.field_type_select?).to be(false)
    end
  end

  describe '#work_item_types' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }
    let_it_be(:incident_type) { build(:work_item_system_defined_type, :incident) }

    let(:custom_field) { build(:custom_field, namespace: namespace) }

    context 'with no associated work item types' do
      it 'returns an empty array' do
        expect(custom_field.work_item_types).to eq([])
      end
    end

    context 'with associated work item types' do
      before do
        custom_field.work_item_type_custom_fields.build(
          work_item_type: task_type,
          namespace: namespace
        )
        custom_field.work_item_type_custom_fields.build(
          work_item_type: issue_type,
          namespace: namespace
        )
        custom_field.work_item_type_custom_fields.build(
          work_item_type: incident_type,
          namespace: namespace
        )
      end

      it 'returns all associated work item types' do
        types = custom_field.work_item_types

        expect(types).to contain_exactly(issue_type, task_type, incident_type)
      end

      it 'sorts types by name (case-insensitive)' do
        types = custom_field.work_item_types
        type_names = types.map(&:name)

        expect(type_names).to eq(type_names.sort_by(&:downcase))
      end
    end
  end

  describe '#work_item_types=' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }
    let_it_be(:incident_type) { build(:work_item_system_defined_type, :incident) }

    let(:custom_field) { build(:custom_field, namespace: namespace) }

    context 'for a new record' do
      it 'builds associations for type objects' do
        custom_field.work_item_types = [issue_type, task_type]

        expect(custom_field.work_item_type_custom_fields.size).to eq(2)
        expect(custom_field.work_item_type_custom_fields.map(&:work_item_type))
          .to contain_exactly(issue_type, task_type)
      end

      it 'builds associations for mixed types and IDs' do
        custom_field.work_item_types = [issue_type, task_type.id]

        expect(custom_field.work_item_type_custom_fields.size).to eq(2)
        type_ids = custom_field.work_item_type_custom_fields.map(&:work_item_type_id)
        expect(type_ids).to contain_exactly(issue_type.id, task_type.id)
      end

      it 'sets the namespace on built associations' do
        custom_field.work_item_types = [issue_type]

        expect(custom_field.work_item_type_custom_fields.first.namespace).to eq(namespace)
      end

      it 'handles empty array' do
        custom_field.work_item_types = []

        expect(custom_field.work_item_type_custom_fields).to be_empty
      end

      it 'handles nil' do
        custom_field.work_item_types = nil

        expect(custom_field.work_item_type_custom_fields).to be_empty
      end

      it 'does not mark associations for destruction on new records' do
        custom_field.work_item_types = [issue_type]

        expect(custom_field.work_item_type_custom_fields.none?(&:marked_for_destruction?)).to be true
      end
    end

    context 'for an existing record' do
      let!(:custom_field) do
        create(:custom_field, namespace: namespace).tap do |cf|
          cf.work_item_type_custom_fields.create!(
            work_item_type: issue_type,
            namespace: namespace
          )
          cf.work_item_type_custom_fields.create!(
            work_item_type: task_type,
            namespace: namespace
          )
        end
      end

      it 'keeps existing associations that are still in the list' do
        custom_field.work_item_types = [issue_type, task_type, incident_type]

        existing_associations = custom_field.work_item_type_custom_fields
          .reject(&:marked_for_destruction?)

        expect(existing_associations.map(&:work_item_type_id))
          .to include(issue_type.id, task_type.id)
      end

      it 'marks associations for destruction when removed' do
        custom_field.work_item_types = [issue_type]

        marked = custom_field.work_item_type_custom_fields
          .select(&:marked_for_destruction?)

        expect(marked.size).to eq(1)
        expect(marked.first.work_item_type_id).to eq(task_type.id)
      end

      it 'adds new associations' do
        custom_field.work_item_types = [issue_type, task_type, incident_type]

        new_associations = custom_field.work_item_type_custom_fields
          .select(&:new_record?)

        expect(new_associations.size).to eq(1)
        expect(new_associations.first.work_item_type_id).to eq(incident_type.id)
      end

      it 'handles complete replacement' do
        custom_field.work_item_types = [incident_type]

        marked = custom_field.work_item_type_custom_fields
          .select(&:marked_for_destruction?)
        new_assocs = custom_field.work_item_type_custom_fields
          .select(&:new_record?)

        expect(marked.map(&:work_item_type_id))
          .to contain_exactly(issue_type.id, task_type.id)
        expect(new_assocs.map(&:work_item_type_id))
          .to contain_exactly(incident_type.id)
      end

      it 'handles setting to empty array' do
        custom_field.work_item_types = []

        marked = custom_field.work_item_type_custom_fields
          .select(&:marked_for_destruction?)

        expect(marked.size).to eq(2)
        expect(marked.map(&:work_item_type_id))
          .to contain_exactly(issue_type.id, task_type.id)
      end

      it 'does not create duplicate associations' do
        custom_field.work_item_types = [issue_type, task_type]

        new_associations = custom_field.work_item_type_custom_fields
          .select(&:new_record?)

        expect(new_associations).to be_empty
      end

      it 'works with mixed types and IDs' do
        custom_field.work_item_types = [issue_type, incident_type.id]

        marked = custom_field.work_item_type_custom_fields
          .select(&:marked_for_destruction?)
        new_assocs = custom_field.work_item_type_custom_fields
          .select(&:new_record?)

        expect(marked.map(&:work_item_type_id)).to contain_exactly(task_type.id)
        expect(new_assocs.map(&:work_item_type_id)).to contain_exactly(incident_type.id)
      end

      it 'persists changes when saved' do
        custom_field.work_item_types = [issue_type, incident_type]
        custom_field.save!

        custom_field.reload

        expect(custom_field.work_item_types.map(&:id))
          .to contain_exactly(issue_type.id, incident_type.id)
      end
    end

    context 'for edge cases' do
      it 'handles duplicate types in input' do
        custom_field.work_item_types = [issue_type, issue_type, task_type]

        expect(custom_field.work_item_type_custom_fields.size).to eq(2)
        expect(custom_field.work_item_type_custom_fields.map(&:work_item_type_id))
          .to contain_exactly(issue_type.id, task_type.id)
      end

      it 'handles duplicate IDs in input' do
        custom_field.work_item_types = [issue_type.id, issue_type.id, task_type.id]

        expect(custom_field.work_item_type_custom_fields.size).to eq(2)
      end

      it 'filters out nil values' do
        custom_field.work_item_types = [issue_type, nil, task_type]

        expect(custom_field.work_item_type_custom_fields.size).to eq(2)
        expect(custom_field.work_item_type_custom_fields.map(&:work_item_type))
          .to contain_exactly(issue_type, task_type)
      end
    end

    context 'with converted custom work item types' do
      let_it_be(:converted_custom_type) do
        create(:work_item_custom_type, :converted_from_issue, namespace: namespace)
      end

      it 'uses converted_from_system_defined_type_identifier as work_item_type_id' do
        custom_field.work_item_types = [converted_custom_type]

        expect(custom_field.work_item_type_custom_fields.size).to eq(1)
        expect(custom_field.work_item_type_custom_fields.first.work_item_type_id)
          .to eq(converted_custom_type.converted_from_system_defined_type_identifier)
      end

      it 'allows querying custom fields by the persistable type id' do
        custom_field.work_item_types = [converted_custom_type]
        custom_field.save!

        found_fields = described_class.with_work_item_types(
          [converted_custom_type.converted_from_system_defined_type_identifier]
        )

        expect(found_fields).to include(custom_field)
      end
    end
  end

  describe '#reset_ordered_associations' do
    let_it_be(:namespace) { create(:group) }
    let_it_be(:custom_field) { create(:custom_field, namespace: namespace) }
    let_it_be(:option_1) { create(:custom_field_select_option, custom_field: custom_field, position: 2) }
    let_it_be(:option_2) { create(:custom_field_select_option, custom_field: custom_field, position: 1) }

    it 'resets select_options but not work_item_types' do
      expect(custom_field.select_options).to receive(:reset).and_call_original
      expect(custom_field.work_item_types).not_to receive(:reset)

      custom_field.reset_ordered_associations
    end
  end
end
