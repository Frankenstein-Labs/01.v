# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::WeightsSource, feature_category: :team_planning do
  subject(:work_item_weights_source) { build(:work_item_weights_source) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }
  end

  describe 'validations' do
    describe 'namespace' do
      subject { build(:work_item_weights_source, work_item: nil) }

      it { is_expected.to validate_presence_of(:namespace) }
    end

    it { is_expected.to validate_presence_of(:work_item) }

    describe '#copy_namespace_from_work_item' do
      let(:work_item) { create(:work_item) }

      it 'copies namespace_id from the associated work item' do
        expect do
          work_item_weights_source.work_item = work_item
          work_item_weights_source.valid?
        end.to change { work_item_weights_source.namespace_id }.from(nil).to(work_item.namespace_id)
      end
    end
  end

  describe '.upsert_rolled_up_weights_for' do
    let_it_be(:group) { create(:group) }
    let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

    let_it_be_with_reload(:children) do
      create_list(:work_item, 4, :issue, namespace: group).each do |child|
        create(:parent_link, work_item: child, work_item_parent: work_item)
      end
    end

    context 'with various children weights' do
      before do
        children[0].update!(weight: 3)
        children[1].update!(weight: 4, state: :closed)

        # Rolled up weights will be counted and set weight will be ignored
        children[2].update!(weight: 10)
        create(:work_item_weights_source, work_item: children[2], rolled_up_weight: 5, rolled_up_completed_weight: 1)

        # rolled_up_weight will be counted as completed because this is closed
        children[3].update!(weight: nil, state: :closed)
        create(:work_item_weights_source, work_item: children[3], rolled_up_weight: 7, rolled_up_completed_weight: 2)
      end

      it 'inserts the correct rolled up weights for the parent work item' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 19,
          rolled_up_completed_weight: 12
        )
      end

      context 'when existing weight sources record exists' do
        before_all do
          create(:work_item_weights_source, work_item: work_item, rolled_up_weight: 99, rolled_up_completed_weight: 99)
        end

        it 'updates the existing record' do
          expect { described_class.upsert_rolled_up_weights_for(work_item) }
            .to change { work_item.weights_source.reload.rolled_up_weight }.from(99).to(19)
            .and change { work_item.weights_source.reload.rolled_up_completed_weight }.from(99).to(12)
        end

        context 'when all children are removed' do
          before do
            WorkItems::ParentLink.delete_all
          end

          it 'sets null rolled up weights' do
            expect { described_class.upsert_rolled_up_weights_for(work_item) }
              .to change { work_item.weights_source.reload.rolled_up_weight }.from(99).to(nil)
              .and change { work_item.weights_source.reload.rolled_up_completed_weight }.from(99).to(0)
          end
        end
      end
    end

    context 'when children have set weights' do
      before do
        children[0].update!(weight: 1)
        children[1].update!(weight: 2)
        children[2].update!(weight: 3, state: :closed)
        children[3].update!(weight: 4, state: :closed)
      end

      it 'computes the rolled up values from the set weights' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 10,
          rolled_up_completed_weight: 7
        )
      end
    end

    context 'when children have rolled up weights' do
      before do
        create(:work_item_weights_source, work_item: children[0], rolled_up_weight: 1, rolled_up_completed_weight: 1)
        create(:work_item_weights_source, work_item: children[1], rolled_up_weight: 2, rolled_up_completed_weight: 1)
        create(:work_item_weights_source, work_item: children[2], rolled_up_weight: 3, rolled_up_completed_weight: 1)

        # When work item is closed, we count the total weight of 4 as completed even if it has some open descendants.
        children[3].update!(state: :closed)
        create(:work_item_weights_source, work_item: children[3], rolled_up_weight: 4, rolled_up_completed_weight: 1)
      end

      it 'computes the rolled up values from the rolled up values of the children' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 10,
          rolled_up_completed_weight: 7
        )
      end
    end

    context 'when a child has set weight and rolled up weights' do
      before do
        children[0].update!(weight: 5)
        create(:work_item_weights_source, work_item: children[0], rolled_up_weight: 2, rolled_up_completed_weight: 1)
      end

      it 'prioritizes the rolled up weight over the set weight' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 2,
          rolled_up_completed_weight: 1
        )
      end

      context 'when child is closed' do
        before do
          children[0].update!(state: :closed)
        end

        it 'counts the full rolled up weight as completed' do
          described_class.upsert_rolled_up_weights_for(work_item)

          expect(work_item.weights_source.reload).to have_attributes(
            rolled_up_weight: 2,
            rolled_up_completed_weight: 2
          )
        end
      end
    end

    context 'when children have no weights and existing record exists' do
      before do
        create(:work_item_weights_source, work_item: work_item, rolled_up_weight: 99, rolled_up_completed_weight: 99)
      end

      it 'updates the recoord with null weights' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: nil,
          rolled_up_completed_weight: 0
        )
      end
    end

    context 'when work item is not persisted' do
      it 'returns nil' do
        expect(described_class.upsert_rolled_up_weights_for(build(:work_item))).to be_nil
      end
    end

    describe 'state change scenarios' do
      context 'when all children are initially open' do
        before do
          children[0].update!(weight: 2, state: :opened)
          children[1].update!(weight: 3, state: :opened)
          children[2].update!(weight: nil, state: :opened)
          children[3].update!(weight: 4, state: :opened)
        end

        it 'has rolled_up_completed_weight of 0' do
          described_class.upsert_rolled_up_weights_for(work_item)

          expect(work_item.weights_source.reload).to have_attributes(
            rolled_up_weight: 9,
            rolled_up_completed_weight: 0
          )
        end

        context 'when some children are closed' do
          before do
            children[0].update!(state: :closed)  # weight: 2
            children[1].update!(state: :closed)  # weight: 3
          end

          it 'includes closed children weights in rolled_up_completed_weight' do
            described_class.upsert_rolled_up_weights_for(work_item)

            expect(work_item.weights_source.reload).to have_attributes(
              rolled_up_weight: 9,
              rolled_up_completed_weight: 5 # 2 + 3
            )
          end
        end

        context 'when all children are closed' do
          before do
            children.each { |child| child.update!(state: :closed) }
          end

          it 'includes all children weights in rolled_up_completed_weight' do
            described_class.upsert_rolled_up_weights_for(work_item)

            expect(work_item.weights_source.reload).to have_attributes(
              rolled_up_weight: 9,
              rolled_up_completed_weight: 9
            )
          end
        end

        context 'when children are reopened after being closed' do
          before do
            # Close all children first
            children.each { |child| child.update!(state: :closed) }
            described_class.upsert_rolled_up_weights_for(work_item)

            # Then reopen some children
            children[0].update!(state: :opened)  # weight: 2
            children[1].update!(state: :opened)  # weight: 3
          end

          it 'removes reopened children weights from rolled_up_completed_weight' do
            described_class.upsert_rolled_up_weights_for(work_item)

            expect(work_item.weights_source.reload).to have_attributes(
              rolled_up_weight: 9,
              rolled_up_completed_weight: 4 # 0 + 4 (only closed children)
            )
          end
        end
      end

      context 'with nested hierarchies and state changes' do
        let_it_be_with_reload(:grandchild_1) { create(:work_item, :task, namespace: group, weight: 1) }
        let_it_be(:grandchild_2) { create(:work_item, :task, namespace: group, weight: 2) }

        before do
          # Create nested hierarchy: work_item -> children[0] -> grandchildren
          create(:parent_link, work_item: grandchild_1, work_item_parent: children[0])
          create(:parent_link, work_item: grandchild_2, work_item_parent: children[0])

          # Set up weights
          children[0].update!(weight: 5) # Has children, so rolled_up_weight will be calculated
          children[1].update!(weight: 3, state: :closed)
        end

        it 'correctly calculates nested completed weights' do
          # First calculate grandchildren weights for children[0]
          described_class.upsert_rolled_up_weights_for(children[0])
          # Then calculate parent weights
          described_class.upsert_rolled_up_weights_for(work_item)

          expect(children[0].weights_source.reload).to have_attributes(
            rolled_up_weight: 3, # 1 + 2 (grandchildren)
            rolled_up_completed_weight: 0 # Both grandchildren are open
          )

          expect(work_item.weights_source.reload).to have_attributes(
            rolled_up_weight: 6, # 3 (from children[0]) + 3 (from children[1])
            rolled_up_completed_weight: 3 # Only children[1] is closed
          )
        end

        context 'when closing children[0] with open grandchildren' do
          before do
            described_class.upsert_rolled_up_weights_for(children[0])
            children[0].update!(state: :closed)
          end

          it 'includes full rolled_up_weight of closed child as completed' do
            described_class.upsert_rolled_up_weights_for(work_item)

            expect(work_item.weights_source.reload).to have_attributes(
              rolled_up_weight: 6, # 3 + 3
              rolled_up_completed_weight: 6  # 3 (from closed children[0]) + 3 (from closed children[1])
            )
          end
        end

        context 'when closing grandchildren' do
          before do
            grandchild_1.update!(state: :closed)
            described_class.upsert_rolled_up_weights_for(children[0])
          end

          it 'propagates completed weights up the hierarchy' do
            described_class.upsert_rolled_up_weights_for(work_item)

            expect(children[0].weights_source.reload).to have_attributes(
              rolled_up_weight: 3,
              rolled_up_completed_weight: 1  # Only grandchild_1 is closed
            )

            expect(work_item.weights_source.reload).to have_attributes(
              rolled_up_weight: 6,
              rolled_up_completed_weight: 4  # 1 (from children[0]) + 3 (from children[1])
            )
          end
        end
      end
    end
  end
end
