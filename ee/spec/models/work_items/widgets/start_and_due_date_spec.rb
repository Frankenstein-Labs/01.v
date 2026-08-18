# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::StartAndDueDate, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let(:work_item_type) { build(:work_item_system_defined_type, :issue) }
  let(:work_item) { build_stubbed(:work_item, work_item_type: work_item_type, project: project) }

  subject(:widget) { described_class.new(work_item) }

  describe '.sync_params' do
    specify do
      expect(described_class.sync_params).to contain_exactly(
        :start_date_fixed,
        :start_date_is_fixed,
        :due_date_fixed,
        :due_date_is_fixed
      )
    end
  end

  describe '#can_rollup?' do
    context 'when work_item type has no allowed child types' do
      let(:work_item_type) { build(:work_item_system_defined_type, :key_result) }

      it 'returns false' do
        expect(widget.can_rollup?).to be(false)
      end
    end

    context 'when work_item type has allowed child types' do
      let(:work_item_type) { build(:work_item_system_defined_type, :issue) }

      it 'returns true' do
        expect(widget.can_rollup?).to be(true)
      end
    end
  end

  context 'when work_item cannot have children' do
    before do
      allow(work_item_type).to receive(:allowed_child_types).and_return([])
    end

    describe '#fixed?' do
      specify { expect(widget.fixed?).to be(true) }
    end

    describe '#start_date' do
      specify { expect(widget.start_date).to eq(work_item.start_date) }
    end

    describe '#start_date_sourcing_work_item' do
      specify { expect(widget.start_date_sourcing_work_item).to be_nil }
    end

    describe '#start_date_sourcing_milestone' do
      specify { expect(widget.start_date_sourcing_milestone).to be_nil }
    end

    describe '#due_date' do
      specify { expect(widget.due_date).to eq(work_item.due_date) }
    end

    describe '#due_date_sourcing_work_item' do
      specify { expect(widget.due_date_sourcing_work_item).to be_nil }
    end

    describe '#due_date_sourcing_milestone' do
      specify { expect(widget.due_date_sourcing_milestone).to be_nil }
    end
  end

  context 'when work_item can have children' do
    before do
      allow(work_item.work_item_type).to receive(:allowed_child_types).and_return([:subtype])
    end

    describe '#fixed?' do
      # Rules defined on https://gitlab.com/groups/gitlab-org/-/epics/11409#rules
      where(
        :wi_start_date,
        :wi_due_date,
        :start_date_is_fixed,
        :start_date_fixed,
        :due_date_is_fixed,
        :due_date_fixed,
        :expected
      ) do
        # when nothing is set, it's not fixed
        nil | nil | false | nil | false | nil | false
        # when either work item dates are set,
        # but dates source is empty, it's not fixed
        1.day.ago | nil | false | nil | false | nil | false
        nil | 1.day.from_now | false | nil | false | nil | false
        1.day.ago | 1.day.from_now | false | nil | false | nil | false
        # when dates_source dates are set, ignore work_item dates and
        # calculate based only on dates sources values
        1.day.ago | 1.day.from_now | false | nil | false | 2.days.from_now | false
        1.day.ago | 1.day.from_now | false | 2.days.ago | false | nil | false
        1.day.ago | 1.day.from_now | false | 2.days.ago | false | 2.days.from_now | false
        # if only one _is_fixed is true and has value, it's fixed
        1.day.ago | 1.day.from_now | true | 2.days.ago | false | nil | true
        1.day.ago | 1.day.from_now | false | nil | true | 2.days.from_now | true
        # if both _is_fixed is true, it's fixed
        1.day.ago | 1.day.from_now | true | nil | true | nil | true
      end

      with_them do
        before do
          work_item.assign_attributes(
            start_date: wi_start_date,
            due_date: wi_due_date
          )

          work_item.build_dates_source(
            start_date_is_fixed: start_date_is_fixed,
            start_date_fixed: start_date_fixed,
            due_date_is_fixed: due_date_is_fixed,
            due_date_fixed: due_date_fixed
          )
        end

        specify { expect(widget.fixed?).to eq(expected) }
      end
    end

    describe '#start_date' do
      where(:start_date_is_fixed, :start_date, :start_date_fixed, :expected) do
        false | nil | nil | nil
        false | nil | 1.day.ago.to_date | nil
        false | 2.days.ago.to_date | nil | 2.days.ago.to_date
        false | 2.days.ago.to_date | 3.days.ago.to_date | 2.days.ago.to_date
        true | 2.days.ago.to_date | nil | 2.days.ago.to_date
        true | 2.days.ago.to_date | 3.days.ago.to_date | 3.days.ago.to_date
      end

      with_them do
        before do
          work_item.build_dates_source(
            start_date: start_date,
            start_date_fixed: start_date_fixed,
            start_date_is_fixed: start_date_is_fixed
          )
        end

        specify { expect(widget.start_date).to eq(expected) }
      end
    end

    describe '#due_date' do
      where(:due_date_is_fixed, :due_date, :due_date_fixed, :expected) do
        false | nil | nil | nil
        false | nil | 1.day.ago.to_date | nil
        false | 2.days.ago.to_date | nil | 2.days.ago.to_date
        false | 2.days.ago.to_date | 3.days.ago.to_date | 2.days.ago.to_date
        true | 2.days.ago.to_date | nil | 2.days.ago.to_date
        true | 2.days.ago.to_date | 3.days.ago.to_date | 3.days.ago.to_date
      end

      with_them do
        before do
          work_item.build_dates_source(
            due_date: due_date,
            due_date_fixed: due_date_fixed,
            due_date_is_fixed: due_date_is_fixed
          )
        end

        specify { expect(widget.due_date).to eq(expected) }
      end
    end

    context 'and rolling up start_date from a child work_item' do
      let(:child_work_item) { build_stubbed(:work_item, :task) }

      before do
        work_item.build_dates_source(start_date: Time.zone.today, start_date_sourcing_work_item: child_work_item)
      end

      describe '#start_date_sourcing_work_item' do
        specify { expect(widget.start_date_sourcing_work_item).to eq(child_work_item) }
      end
    end

    context 'and rolling up due_date from a child work_item' do
      let(:child_work_item) { build_stubbed(:work_item, :task) }

      before do
        work_item.build_dates_source(due_date: Time.zone.today, due_date_sourcing_work_item: child_work_item)
      end

      describe '#due_date_sourcing_work_item' do
        specify { expect(widget.due_date_sourcing_work_item).to eq(child_work_item) }
      end
    end

    context 'and rolling up start_date from a child work_item milestone' do
      let(:milestone) { build_stubbed(:milestone) }

      before do
        work_item.build_dates_source(start_date: Time.zone.today, start_date_sourcing_milestone: milestone)
      end

      describe '#start_date_sourcing_milestone' do
        specify { expect(widget.start_date_sourcing_milestone).to eq(milestone) }
      end
    end

    context 'and rolling up due_date from a child work_item milestone' do
      let(:milestone) { build_stubbed(:milestone) }

      before do
        work_item.build_dates_source(due_date: Time.zone.today, due_date_sourcing_milestone: milestone)
      end

      describe '#due_date_sourcing_milestone' do
        specify { expect(widget.due_date_sourcing_milestone).to eq(milestone) }
      end
    end
  end
end
