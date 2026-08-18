# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::Lifecycle, feature_category: :team_planning do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:open_status) { create(:work_item_custom_status, :open, namespace: namespace) }
  let_it_be(:closed_status) { create(:work_item_custom_status, :closed, namespace: namespace) }
  let_it_be(:duplicate_status) { create(:work_item_custom_status, :duplicate, namespace: namespace) }
  let_it_be(:in_dev_status) do
    create(:work_item_custom_status, category: :in_progress, name: 'In dev', namespace: namespace)
  end

  subject(:custom_lifecycle) do
    build(:work_item_custom_lifecycle,
      namespace: namespace,
      default_open_status: open_status,
      default_closed_status: closed_status,
      default_duplicate_status: duplicate_status
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:default_open_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:default_closed_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:default_duplicate_status).class_name('WorkItems::Statuses::Custom::Status') }
    it { is_expected.to belong_to(:created_by) }
    it { is_expected.to belong_to(:updated_by) }
    it { is_expected.to have_many(:lifecycle_statuses) }
    it { is_expected.to have_many(:statuses).through(:lifecycle_statuses) }
    it { is_expected.to have_many(:type_custom_lifecycles) }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(64) }
    it { is_expected.to validate_presence_of(:default_open_status) }
    it { is_expected.to validate_presence_of(:default_closed_status) }
    it { is_expected.to validate_presence_of(:default_duplicate_status) }

    context 'with uniqueness validations' do
      subject(:custom_lifecycle) { create(:work_item_custom_lifecycle) }

      it { is_expected.to validate_uniqueness_of(:name).scoped_to(:namespace_id) }
    end

    describe 'status limit validations' do
      let_it_be(:one_more_status) { create(:work_item_custom_status, namespace: namespace) }

      before do
        stub_const('WorkItems::Statuses::Custom::Lifecycle::MAX_STATUSES_PER_LIFECYCLE', 3)
      end

      it 'is invalid when exceeding maximum allowed statuses' do
        custom_lifecycle.statuses << one_more_status

        expect(custom_lifecycle).not_to be_valid
        expect(custom_lifecycle.errors[:base]).to include('Lifecycle can only have a maximum of 3 statuses.')
      end
    end

    describe 'lifecycle per namespace limit validations' do
      let_it_be_with_reload(:existing_lifecycle) do
        create(:work_item_custom_lifecycle,
          namespace: namespace,
          default_open_status: open_status,
          default_closed_status: closed_status,
          default_duplicate_status: duplicate_status
        )
      end

      before do
        stub_const('WorkItems::Statuses::Custom::Lifecycle::MAX_LIFECYCLES_PER_NAMESPACE', 1)
      end

      it 'is invalid when exceeding maximum allowed lifecycles' do
        expect(custom_lifecycle).not_to be_valid

        expect(custom_lifecycle.errors[:namespace]).to include('can only have a maximum of 1 lifecycles.')
      end

      it 'allows updating attributes of an existing lifecycle when limit is reached' do
        existing_lifecycle.name = 'Updated Name'

        expect(existing_lifecycle).to be_valid
      end
    end

    describe '#validate_default_status_categories' do
      context 'with invalid category combinations' do
        it 'is invalid when default_open_status has wrong category' do
          custom_lifecycle = build(:work_item_custom_lifecycle,
            namespace: namespace,
            default_open_status: closed_status,
            default_closed_status: closed_status,
            default_duplicate_status: duplicate_status
          )

          expect(custom_lifecycle).to be_invalid
          expect(custom_lifecycle.errors[:default_open_status])
            .to include(/must be of category triage or to_do or in_progress/)
        end

        it 'is invalid when default_closed_status has wrong category' do
          custom_lifecycle = build(:work_item_custom_lifecycle,
            namespace: namespace,
            default_open_status: open_status,
            default_closed_status: open_status,
            default_duplicate_status: duplicate_status
          )

          expect(custom_lifecycle).to be_invalid
          expect(custom_lifecycle.errors[:default_closed_status]).to include(/must be of category done or canceled/)
        end

        it 'is invalid when default_duplicate_status has wrong category' do
          custom_lifecycle = build(:work_item_custom_lifecycle,
            namespace: namespace,
            default_open_status: open_status,
            default_closed_status: closed_status,
            default_duplicate_status: open_status
          )

          expect(custom_lifecycle).to be_invalid
          expect(custom_lifecycle.errors[:default_duplicate_status]).to include(/must be of category done or canceled/)
        end
      end
    end
  end

  describe 'callbacks' do
    describe '#ensure_default_statuses_in_lifecycle' do
      context 'when creating a new lifecycle' do
        it 'automatically adds default statuses to the lifecycle statuses' do
          expect { custom_lifecycle.save! }.to change { custom_lifecycle.statuses.count }.from(0).to(3)

          expect(custom_lifecycle.statuses).to contain_exactly(open_status, closed_status, duplicate_status)
        end
      end

      context 'when updating an existing lifecycle' do
        let_it_be(:new_open_status) do
          create(:work_item_custom_status, :open, name: "Ready for development", namespace: namespace)
        end

        before do
          custom_lifecycle.save!
        end

        it 'adds new default statuses to the lifecycle statuses' do
          expect do
            custom_lifecycle.update!(default_open_status: new_open_status)
          end.to change { custom_lifecycle.statuses.count }.by(1)

          expect(custom_lifecycle.statuses)
            .to contain_exactly(open_status, new_open_status, closed_status, duplicate_status)
        end

        it 'does not duplicate statuses already in the collection' do
          expect do
            custom_lifecycle.update!(default_open_status: open_status)
          end.not_to change { custom_lifecycle.statuses.count }
        end
      end
    end
  end

  describe 'included modules' do
    subject { described_class }

    it { is_expected.to include(WorkItems::Statuses::SharedConstants) }
  end

  describe '#ordered_statuses' do
    let_it_be(:in_review_status) do
      create(:work_item_custom_status, category: :in_progress, name: 'In review', namespace: namespace)
    end

    subject(:custom_lifecycle) do
      create(:work_item_custom_lifecycle,
        namespace: namespace,
        default_open_status: open_status,
        default_closed_status: closed_status,
        default_duplicate_status: duplicate_status
      )
    end

    it 'returns statuses ordered by category, position, and id' do
      create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: in_review_status, position: 2)
      create(:work_item_custom_lifecycle_status, lifecycle: custom_lifecycle, status: in_dev_status, position: 1)

      ordered_statuses = custom_lifecycle.ordered_statuses

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

  describe '#has_status_id?' do
    before do
      custom_lifecycle.save!
    end

    it "returns true if the status exist in the lifecycle" do
      expect(custom_lifecycle.has_status_id?(open_status.id)).to be true
    end

    it "returns false if the statuts does not exists in the lifecycle" do
      expect(custom_lifecycle.has_status_id?(in_dev_status.id)).to be false
    end
  end

  describe '#default_statuses' do
    it 'returns an array of default statuses' do
      expect(custom_lifecycle.default_statuses).to contain_exactly(open_status, closed_status, duplicate_status)
    end
  end

  describe '#default_status_for_work_item' do
    subject(:default_status) { custom_lifecycle.default_status_for_work_item(work_item) }

    context 'for open work item' do
      let(:work_item) { build(:work_item, :opened) }

      it 'returns correct status' do
        is_expected.to eq(custom_lifecycle.default_open_status)
      end
    end

    context 'for duplicated work item' do
      let(:work_item) { build(:work_item, :closed, duplicated_to_id: 1) }

      it 'returns correct status' do
        is_expected.to eq(custom_lifecycle.default_duplicate_status)
      end
    end

    context 'for closed work item' do
      let(:work_item) { build(:work_item, :closed) }

      it 'returns correct status' do
        is_expected.to eq(custom_lifecycle.default_closed_status)
      end
    end
  end

  describe '#in_use?' do
    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'when lifecycle is associated with a work item type in the namespace' do
      before do
        create(:work_item_type_custom_lifecycle,
          work_item_type: build(:work_item_system_defined_type, :issue),
          lifecycle: custom_lifecycle,
          namespace: namespace
        )
      end

      it 'returns true' do
        expect(custom_lifecycle.in_use?(namespace.id)).to be true
      end
    end

    context 'when lifecycle is not associated with any work item type in the namespace' do
      it 'returns false' do
        expect(custom_lifecycle.in_use?(namespace.id)).to be false
      end
    end
  end

  describe '#role_for_status' do
    let(:lifecycle) do
      build(:work_item_custom_lifecycle,
        namespace: namespace,
        default_open_status: open_status,
        default_closed_status: closed_status,
        default_duplicate_status: duplicate_status
      )
    end

    subject { lifecycle.role_for_status(status) }

    context 'when status is system-defined' do
      let(:status) { build(:work_item_system_defined_status) }

      it { is_expected.to be_nil }
    end

    context 'when status is not a default in the lifecycle' do
      let(:status) { create(:work_item_custom_status) }

      it { is_expected.to be_nil }
    end

    context 'when status is default open status' do
      let(:status) { lifecycle.default_open_status }

      it { is_expected.to eq(:open) }
    end

    context 'when status is default closed status' do
      let(:status) { lifecycle.default_closed_status }

      it { is_expected.to eq(:closed) }
    end

    context 'when status is default duplicate status' do
      let(:status) { lifecycle.default_duplicate_status }

      it { is_expected.to eq(:duplicate) }
    end
  end

  describe '#work_item_types' do
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    it 'returns work item types from type_custom_lifecycles association' do
      create(:work_item_type_custom_lifecycle,
        lifecycle: custom_lifecycle,
        work_item_type: issue_type,
        namespace: namespace
      )
      create(:work_item_type_custom_lifecycle,
        lifecycle: custom_lifecycle,
        work_item_type: task_type,
        namespace: namespace
      )

      expect(custom_lifecycle.work_item_types).to match_array([issue_type, task_type])
    end

    it 'returns empty array when no type_custom_lifecycles exist' do
      expect(custom_lifecycle.work_item_types).to eq([])
    end
  end

  describe '#work_item_types=' do
    let_it_be(:issue_type) { build(:work_item_system_defined_type, :issue) }
    let_it_be(:task_type) { build(:work_item_system_defined_type, :task) }
    let_it_be(:incident_type) { build(:work_item_system_defined_type, :incident) }

    before do
      stub_licensed_features(work_item_status: true)
    end

    context 'for a new record' do
      it 'builds type_custom_lifecycles for work item type objects' do
        custom_lifecycle.work_item_types = [issue_type, task_type]

        expect(custom_lifecycle.type_custom_lifecycles.size).to eq(2)
        expect(custom_lifecycle.work_item_types).to match_array([issue_type, task_type])
      end

      it 'builds type_custom_lifecycles for work item type IDs' do
        custom_lifecycle.work_item_types = [issue_type.id, task_type.id]

        expect(custom_lifecycle.type_custom_lifecycles.size).to eq(2)
        expect(custom_lifecycle.work_item_types).to match_array([issue_type, task_type])
      end

      it 'builds type_custom_lifecycles for mixed types and IDs' do
        custom_lifecycle.work_item_types = [issue_type, task_type.id]

        expect(custom_lifecycle.work_item_types).to match_array([issue_type, task_type])
      end

      it 'sets the namespace on built associations' do
        custom_lifecycle.work_item_types = [issue_type]

        expect(custom_lifecycle.type_custom_lifecycles.first.namespace).to eq(namespace)
      end

      it 'handles empty array' do
        custom_lifecycle.work_item_types = []

        expect(custom_lifecycle.work_item_types).to be_empty
      end

      it 'handles nil by converting to empty array' do
        custom_lifecycle.work_item_types = nil

        expect(custom_lifecycle.work_item_types).to be_empty
      end

      it 'filters out nil values from the array' do
        custom_lifecycle.work_item_types = [issue_type, nil, task_type]

        expect(custom_lifecycle.work_item_types.size).to eq(2)
        expect(custom_lifecycle.work_item_types).to match_array([issue_type, task_type])
      end

      it 'does not mark associations for destruction on new records' do
        custom_lifecycle.work_item_types = [issue_type]

        expect(custom_lifecycle.type_custom_lifecycles.none?(&:marked_for_destruction?))
          .to be true
      end
    end

    context 'for an existing record' do
      before do
        create(:work_item_type_custom_lifecycle,
          lifecycle: custom_lifecycle,
          work_item_type: issue_type,
          namespace: namespace
        )
        create(:work_item_type_custom_lifecycle,
          lifecycle: custom_lifecycle,
          work_item_type: task_type,
          namespace: namespace
        )
        custom_lifecycle.reload
      end

      it 'keeps existing associations that are still in the list' do
        custom_lifecycle.work_item_types = [issue_type, task_type, incident_type]

        existing_associations = custom_lifecycle.type_custom_lifecycles
          .reject(&:marked_for_destruction?)

        expect(existing_associations.map(&:work_item_type_id))
          .to include(issue_type.id, task_type.id)
      end

      it 'marks associations for destruction when removed from the list' do
        custom_lifecycle.work_item_types = [issue_type]

        marked = custom_lifecycle.type_custom_lifecycles
          .select(&:marked_for_destruction?)

        expect(marked.size).to eq(1)
        expect(marked.first.work_item_type_id).to eq(task_type.id)
      end

      it 'adds new associations for new types' do
        custom_lifecycle.work_item_types = [issue_type, task_type, incident_type]

        new_associations = custom_lifecycle.type_custom_lifecycles
          .select(&:new_record?)

        expect(new_associations.size).to eq(1)
        expect(new_associations.first.work_item_type_id).to eq(incident_type.id)
      end

      it 'handles complete replacement of types' do
        custom_lifecycle.work_item_types = [incident_type]

        marked = custom_lifecycle.type_custom_lifecycles
          .select(&:marked_for_destruction?)
        new_assocs = custom_lifecycle.type_custom_lifecycles
          .select(&:new_record?)

        expect(marked.map(&:work_item_type_id))
          .to match_array([issue_type.id, task_type.id])
        expect(new_assocs.map(&:work_item_type_id))
          .to contain_exactly(incident_type.id)
      end

      it 'marks all associations for destruction when set to empty array' do
        custom_lifecycle.work_item_types = []

        marked = custom_lifecycle.type_custom_lifecycles
          .select(&:marked_for_destruction?)

        expect(marked.size).to eq(2)
        expect(marked.map(&:work_item_type_id))
          .to match_array([issue_type.id, task_type.id])
      end

      it 'does not create duplicate associations' do
        custom_lifecycle.work_item_types = [issue_type, task_type]

        new_associations = custom_lifecycle.type_custom_lifecycles
          .select(&:new_record?)

        expect(new_associations).to be_empty
      end

      it 'works with mixed types and IDs' do
        custom_lifecycle.work_item_types = [issue_type, incident_type.id]

        marked = custom_lifecycle.type_custom_lifecycles
          .select(&:marked_for_destruction?)
        new_assocs = custom_lifecycle.type_custom_lifecycles
          .select(&:new_record?)

        expect(marked.map(&:work_item_type_id)).to contain_exactly(task_type.id)
        expect(new_assocs.map(&:work_item_type_id)).to contain_exactly(incident_type.id)
      end

      context 'with autosave enabled on association' do
        it 'persists changes when lifecycle is saved' do
          custom_lifecycle.work_item_types = [issue_type]
          custom_lifecycle.save!

          custom_lifecycle.reload

          expect(custom_lifecycle.work_item_types.map(&:id))
            .to match_array([issue_type.id])
        end

        it 'deletes marked associations after save and reload' do
          initial_count = custom_lifecycle.type_custom_lifecycles.count
          expect(initial_count).to eq(2)

          custom_lifecycle.work_item_types = [issue_type]
          custom_lifecycle.save!

          custom_lifecycle.reload

          expect(custom_lifecycle.type_custom_lifecycles.count).to eq(1)
          expect(custom_lifecycle.type_custom_lifecycles.first.work_item_type_id)
            .to eq(issue_type.id)
        end
      end
    end

    context 'for edge cases' do
      it 'handles duplicate types in input array' do
        custom_lifecycle.work_item_types = [issue_type, issue_type, task_type]

        type_ids = custom_lifecycle.type_custom_lifecycles.map(&:work_item_type_id)

        expect(type_ids.uniq.size).to be <= 2
      end

      it 'handles duplicate IDs in input array' do
        custom_lifecycle.work_item_types = [issue_type.id, issue_type.id, task_type.id]

        type_ids = custom_lifecycle.type_custom_lifecycles.map(&:work_item_type_id)

        expect(type_ids.uniq.size).to be <= 2
      end

      it 'filters out nil values using compact' do
        custom_lifecycle.work_item_types = [issue_type, nil, task_type, nil]

        expect(custom_lifecycle.type_custom_lifecycles.size).to be >= 2
        expect(custom_lifecycle.type_custom_lifecycles.filter_map(&:work_item_type))
          .to match_array([issue_type, task_type])
      end

      it 'handles empty array without errors' do
        expect { custom_lifecycle.work_item_types = [] }.not_to raise_error
      end

      it 'handles nil input without errors' do
        expect { custom_lifecycle.work_item_types = nil }.not_to raise_error
      end
    end

    context 'with converted custom work item types' do
      let_it_be(:converted_custom_type) do
        create(:work_item_custom_type, :converted_from_issue, namespace: namespace)
      end

      it 'uses converted_from_system_defined_type_identifier as work_item_type_id' do
        custom_lifecycle.work_item_types = [converted_custom_type]

        expect(custom_lifecycle.type_custom_lifecycles.size).to eq(1)
        expect(custom_lifecycle.type_custom_lifecycles.first.work_item_type_id)
          .to eq(converted_custom_type.converted_from_system_defined_type_identifier)
      end

      it 'retrieves the correct work_item_type_ids' do
        custom_lifecycle.work_item_types = [converted_custom_type]

        expect(custom_lifecycle.work_item_type_ids)
          .to contain_exactly(converted_custom_type.converted_from_system_defined_type_identifier)
      end
    end
  end
end
