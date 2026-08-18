# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Statuses::Custom::LifecycleStatus, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:lifecycle) { create(:work_item_custom_lifecycle, namespace: group) }

  subject(:custom_lifecycle_status) { build_stubbed(:work_item_custom_lifecycle_status, lifecycle: lifecycle) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:lifecycle).class_name('WorkItems::Statuses::Custom::Lifecycle') }
    it { is_expected.to belong_to(:status).class_name('WorkItems::Statuses::Custom::Status') }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_numericality_of(:position).only_integer.is_greater_than_or_equal_to(0) }

    context 'with uniqueness validations' do
      subject(:custom_lifecycle_status) { create(:work_item_custom_lifecycle_status) }

      it { is_expected.to validate_uniqueness_of(:status_id).scoped_to(:lifecycle_id) }
    end
  end

  describe 'callbacks' do
    describe '#copy_namespace_from_lifecycle' do
      context 'when namespace is not set' do
        subject(:custom_lifecycle_status) do
          build_stubbed(:work_item_custom_lifecycle_status, namespace: nil, lifecycle: lifecycle)
        end

        it 'copies namespace from lifecycle' do
          expect { custom_lifecycle_status.valid? }
            .to change { custom_lifecycle_status.namespace }
            .from(nil).to(lifecycle.namespace)
        end
      end

      context 'when namespace is already set' do
        it 'does not override the namespace' do
          expect { custom_lifecycle_status.valid? }
            .not_to change { custom_lifecycle_status.namespace }

          expect(custom_lifecycle_status.namespace).to eq(lifecycle.namespace)
        end
      end
    end
  end
end
