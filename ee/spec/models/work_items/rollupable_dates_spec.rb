# frozen_string_literal: true

require "spec_helper"

RSpec.describe WorkItems::RollupableDates, feature_category: :team_planning do
  let_it_be(:sourcing_milestone) { create(:milestone) }
  let_it_be_with_reload(:sourcing_work_item) { create(:work_item, :epic) }
  let_it_be_with_reload(:sourcing_epic) { create(:epic, work_item: sourcing_work_item) }

  context 'when using legacy epics' do
    let(:source) { build_stubbed(:epic) }

    it_behaves_like 'rollupable dates - when can_rollup is false' do
      subject(:rollupable_dates) { described_class.new(source, can_rollup: false) }

      describe '#start_date_sourcing_milestone' do
        before do
          source.assign_attributes(start_date_sourcing_milestone_id: sourcing_milestone.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_milestone).to be_nil }
      end

      describe '#start_date_sourcing_epic' do
        before do
          source.assign_attributes(start_date_sourcing_epic_id: sourcing_epic.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_epic).to be_nil }
      end

      describe '#start_date_sourcing_work_item' do
        before do
          source.assign_attributes(start_date_sourcing_epic_id: sourcing_epic.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_work_item).to be_nil }
      end
    end

    it_behaves_like 'rollupable dates - when can_rollup is true' do
      subject(:rollupable_dates) { described_class.new(source, can_rollup: true) }

      describe '#start_date_sourcing_milestone' do
        before do
          source.assign_attributes(start_date_sourcing_milestone_id: sourcing_milestone.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_milestone).to eq(sourcing_milestone) }
      end

      describe '#start_date_sourcing_epic' do
        before do
          source.assign_attributes(start_date_sourcing_epic_id: sourcing_epic.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_epic).to eq(sourcing_epic) }
      end

      describe '#start_date_sourcing_work_item' do
        context 'when source does not have a sourcing epic id' do
          before do
            source.assign_attributes(start_date_sourcing_epic_id: nil)
          end

          specify { expect(rollupable_dates.start_date_sourcing_work_item).to be_nil }
        end

        context 'when source has a sourcing epic' do
          before do
            source.assign_attributes(start_date_sourcing_epic_id: sourcing_epic.id)
          end

          specify { expect(rollupable_dates.start_date_sourcing_work_item).to eq(sourcing_epic.work_item) }
        end
      end

      describe '#due_date_sourcing_milestone' do
        before do
          source.assign_attributes(due_date_sourcing_milestone_id: sourcing_milestone.id)
        end

        specify { expect(rollupable_dates.due_date_sourcing_milestone).to eq(sourcing_milestone) }
      end

      describe '#due_date_sourcing_epic' do
        before do
          source.assign_attributes(due_date_sourcing_epic_id: sourcing_epic.id)
        end

        specify { expect(rollupable_dates.due_date_sourcing_epic).to eq(sourcing_epic) }
      end

      describe '#due_date_sourcing_work_item' do
        context 'when source does not have a sourcing epic id' do
          before do
            source.assign_attributes(due_date_sourcing_epic_id: nil)
          end

          specify { expect(rollupable_dates.due_date_sourcing_work_item).to be_nil }
        end

        context 'when source has a sourcing epic' do
          before do
            source.assign_attributes(due_date_sourcing_epic_id: sourcing_epic.id)
          end

          specify { expect(rollupable_dates.due_date_sourcing_work_item).to eq(sourcing_epic.work_item) }
        end
      end
    end
  end

  context 'when using work item dates source' do
    let(:source) { build_stubbed(:work_items_dates_source) }

    it_behaves_like 'rollupable dates - when can_rollup is false' do
      subject(:rollupable_dates) { described_class.new(source, can_rollup: false) }

      describe '#start_date_sourcing_milestone' do
        before do
          source.assign_attributes(start_date_sourcing_milestone_id: sourcing_milestone.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_milestone).to be_nil }
      end

      describe '#start_date_sourcing_epic' do
        before do
          source.assign_attributes(start_date_sourcing_work_item_id: sourcing_work_item.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_epic).to be_nil }
      end

      describe '#start_date_sourcing_work_item' do
        before do
          source.assign_attributes(start_date_sourcing_work_item_id: sourcing_work_item.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_work_item).to be_nil }
      end

      describe '#due_date_sourcing_epic' do
        before do
          source.assign_attributes(due_date_sourcing_work_item_id: sourcing_work_item.id)
        end

        specify { expect(rollupable_dates.due_date_sourcing_epic).to be_nil }
      end

      describe '#due_date_sourcing_work_item' do
        before do
          source.assign_attributes(due_date_sourcing_work_item_id: sourcing_work_item.id)
        end

        specify { expect(rollupable_dates.due_date_sourcing_work_item).to be_nil }
      end
    end

    it_behaves_like 'rollupable dates - when can_rollup is true' do
      subject(:rollupable_dates) { described_class.new(source, can_rollup: true) }

      describe '#start_date_sourcing_milestone' do
        before do
          source.assign_attributes(start_date_sourcing_milestone_id: sourcing_milestone.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_milestone).to eq(sourcing_milestone) }
      end

      describe '#start_date_sourcing_epic' do
        context 'when source does not have a sourcing work_item id' do
          before do
            source.assign_attributes(start_date_sourcing_work_item_id: nil)
          end

          specify { expect(rollupable_dates.start_date_sourcing_epic).to be_nil }
        end

        context 'when source has a sourcing work_item' do
          before do
            source.assign_attributes(start_date_sourcing_work_item_id: sourcing_work_item.id)
          end

          specify { expect(rollupable_dates.start_date_sourcing_epic).to eq(sourcing_epic) }
        end
      end

      describe '#start_date_sourcing_work_item' do
        before do
          source.assign_attributes(start_date_sourcing_work_item_id: sourcing_work_item.id)
        end

        specify { expect(rollupable_dates.start_date_sourcing_work_item).to eq(sourcing_work_item) }
      end

      describe '#due_date_sourcing_epic' do
        context 'when source does not have a sourcing work_item id' do
          before do
            source.assign_attributes(due_date_sourcing_work_item_id: nil)
          end

          specify { expect(rollupable_dates.due_date_sourcing_epic).to be_nil }
        end

        context 'when source has a sourcing work_item' do
          before do
            source.assign_attributes(due_date_sourcing_work_item_id: sourcing_work_item.id)
          end

          specify { expect(rollupable_dates.due_date_sourcing_epic).to eq(sourcing_epic) }
        end
      end

      describe '#due_date_sourcing_work_item' do
        before do
          source.assign_attributes(due_date_sourcing_work_item_id: sourcing_work_item.id)
        end

        specify { expect(rollupable_dates.due_date_sourcing_work_item).to eq(sourcing_work_item) }
      end
    end
  end
end
