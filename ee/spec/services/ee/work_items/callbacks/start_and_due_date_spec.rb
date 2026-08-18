# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::StartAndDueDate, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, :epic, namespace: group) }

  let(:widget) { work_item.get_widget(:start_and_due_date) }

  subject(:service) { described_class.new(issuable: work_item, current_user: user, params: params) }

  before do
    stub_licensed_features(epics: true)
  end

  shared_examples "updating work item's dates_source" do
    shared_examples "when widget does not exist in new type" do
      let(:start_date) { Date.today }
      let(:due_date) { 1.week.from_now.to_date }

      before do
        allow(service).to receive(:excluded_in_new_type?).and_return(true)

        work_item.update!(start_date: start_date, due_date: due_date)
        create(:work_items_dates_source, work_item: work_item, start_date: start_date, due_date: due_date)
      end

      it "sets both dates to null" do
        expect { update_dates }
          .to change { work_item.start_date }.from(start_date).to(nil)
          .and change { work_item.due_date }.from(due_date).to(nil)
          .and change { work_item.dates_source&.start_date }.from(start_date).to(nil)
          .and change { work_item.dates_source&.start_date_is_fixed }.from(false).to(true)
          .and change { work_item.dates_source&.due_date }.from(due_date).to(nil)
          .and change { work_item.dates_source&.due_date_is_fixed }.from(false).to(true)
      end
    end

    context "when using fixed dates" do
      let(:start_date) { Date.today }
      let(:due_date) { 1.week.from_now.to_date }

      shared_examples "sets fixed start and due date values" do
        it "correctly sets date values" do
          expect { update_dates }
            .to change { work_item.start_date }.from(nil).to(start_date)
            .and change { work_item.due_date }.from(nil).to(due_date)
            .and change { work_item.dates_source&.start_date }.from(nil).to(start_date)
            .and change { work_item.dates_source&.start_date_fixed }.from(nil).to(start_date)
            .and change { work_item.dates_source&.start_date_is_fixed }.from(nil).to(true)
            .and change { work_item.dates_source&.due_date }.from(nil).to(due_date)
            .and change { work_item.dates_source&.due_date_fixed }.from(nil).to(due_date)
            .and change { work_item.dates_source&.due_date_is_fixed }.from(nil).to(true)
        end
      end

      context "when is_fixed is not provided" do
        let(:params) { { start_date: start_date, due_date: due_date } }

        it_behaves_like "sets fixed start and due date values"
        it_behaves_like "when widget does not exist in new type"
      end

      context "when is_fixed is provided and is true" do
        let(:params) { { is_fixed: true, start_date: start_date, due_date: due_date } }

        it_behaves_like "sets fixed start and due date values"
        it_behaves_like "when widget does not exist in new type"
      end
    end

    context "when using rolled up dates" do
      let(:params) { { is_fixed: false } }

      let_it_be(:child_work_item) do
        create(:work_item, :epic, namespace: group).tap do |child_work_item|
          create(:parent_link, work_item: child_work_item, work_item_parent: work_item)
          create(
            :work_items_dates_source,
            :fixed,
            work_item: child_work_item,
            start_date: 3.days.ago,
            due_date: 3.days.from_now
          )
        end
      end

      it_behaves_like "when widget does not exist in new type"

      it "does not change work item date values" do
        expect { update_dates }
          .to change { work_item.dates_source&.start_date }.from(nil).to(child_work_item.start_date)
          .and change { work_item.dates_source&.start_date_sourcing_work_item_id }.from(nil).to(child_work_item.id)
          .and change { work_item.dates_source&.due_date }.from(nil).to(child_work_item.due_date)
          .and change { work_item.dates_source&.due_date_sourcing_work_item_id }.from(nil).to(child_work_item.id)
          .and not_change { work_item.dates_source&.start_date_fixed }.from(nil)
          .and not_change { work_item.dates_source&.due_date_fixed }.from(nil)
      end
    end
  end

  describe "#before_create" do
    let(:update_dates) { service.before_create }

    it_behaves_like "updating work item's dates_source"
  end

  describe "#before_update" do
    let(:update_dates) { service.before_update }

    it_behaves_like "updating work item's dates_source"
  end
end
