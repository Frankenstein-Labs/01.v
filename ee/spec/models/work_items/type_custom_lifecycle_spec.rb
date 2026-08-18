# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypeCustomLifecycle, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }
  let(:work_item_type) { build(:work_item_system_defined_type, :task) }

  subject(:type_custom_lifecycle) do
    build_stubbed(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type)
  end

  before do
    stub_licensed_features(work_item_status: true)
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:lifecycle).class_name('WorkItems::Statuses::Custom::Lifecycle') }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:work_item_type_id) }
    it { is_expected.to validate_presence_of(:lifecycle) }

    it_behaves_like 'validates work item type ID'

    describe 'uniqueness validation' do
      subject(:type_custom_lifecycle) do
        create(:work_item_type_custom_lifecycle, lifecycle: lifecycle, work_item_type: work_item_type)
      end

      it { is_expected.to validate_uniqueness_of(:work_item_type_id).scoped_to(:namespace_id) }
    end
  end

  describe '.with_namespace_id' do
    let_it_be(:other_group) { create(:group) }
    let_it_be(:other_lifecycle) { create(:work_item_custom_lifecycle, namespace: other_group) }

    let!(:link_in_group) do
      create(:work_item_type_custom_lifecycle,
        lifecycle: lifecycle,
        work_item_type: build(:work_item_system_defined_type, :issue))
    end

    let!(:link_in_other_group) do
      create(:work_item_type_custom_lifecycle,
        lifecycle: other_lifecycle,
        work_item_type: build(:work_item_system_defined_type, :issue))
    end

    it 'returns only the records for the given namespace' do
      expect(described_class.with_namespace_id(group.id)).to contain_exactly(link_in_group)
    end
  end

  describe '#validate_status_widget_availability' do
    context 'when work item type supports status widget' do
      it 'is valid' do
        expect(type_custom_lifecycle).to be_valid
      end
    end

    context 'when work item type does not support status widget' do
      let(:work_item_type) { build(:work_item_system_defined_type, :requirement) }

      it 'is invalid' do
        expect(type_custom_lifecycle).to be_invalid
        expect(type_custom_lifecycle.errors[:work_item_type]).to include('does not support status widget')
      end
    end

    context 'when work_item_status licensed feature is not available' do
      before do
        stub_licensed_features(work_item_status: false)
      end

      it 'is invalid' do
        expect(type_custom_lifecycle).to be_invalid
        expect(type_custom_lifecycle.errors[:work_item_type]).to include('does not support status widget')
      end
    end
  end

  describe 'callbacks' do
    describe '#copy_namespace_from_lifecycle' do
      context 'when namespace is not set' do
        subject(:type_custom_lifecycle) do
          build_stubbed(:work_item_type_custom_lifecycle, namespace: nil, lifecycle: lifecycle,
            work_item_type: work_item_type)
        end

        it 'copies namespace from lifecycle' do
          expect { type_custom_lifecycle.valid? }
            .to change { type_custom_lifecycle.namespace }
            .from(nil).to(lifecycle.namespace)
        end
      end

      context 'when namespace is already set' do
        it 'does not override the namespace' do
          expect { type_custom_lifecycle.valid? }
            .not_to change { type_custom_lifecycle.namespace }

          expect(type_custom_lifecycle.namespace).to eq(lifecycle.namespace)
        end
      end
    end
  end
end
