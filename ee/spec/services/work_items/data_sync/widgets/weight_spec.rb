# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Weight, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:work_item) { create(:work_item, weight: 3) }
  let_it_be_with_reload(:target_work_item) { create(:work_item) }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: {}
    )
  end

  describe '#before_create' do
    context 'when target work item does not have weight widget' do
      before do
        allow(target_work_item).to receive(:get_widget).with(:weight).and_return(false)
      end

      it 'does not copy weight data' do
        expect { callback.before_create }.not_to change { target_work_item.weight }
      end
    end

    context 'when target work item has weight widget' do
      it 'copies the weight data' do
        expect { callback.before_create }.to change { target_work_item.weight }.from(nil).to(3)
      end
    end
  end

  describe "after_create" do
    context 'when target work item does not have weight widget' do
      before do
        allow(target_work_item).to receive(:get_widget).with(:weight).and_return(false)
      end

      it 'does not copy weight data' do
        expect { callback.after_create }.not_to change { target_work_item.weights_source }
      end
    end

    context "when target work item has weight widget" do
      context "when work item does not have weights source" do
        it "does not copy the weight data" do
          expect { callback.after_create }.not_to change { target_work_item.weights_source }
        end
      end

      context 'when work item has weights source' do
        let!(:weights_source) { create(:work_item_weights_source, work_item: work_item) }

        it "copies the weight data" do
          expect(target_work_item.weights_source).to be_nil

          callback.after_create

          target_weights_source = target_work_item.weights_source

          expect(target_weights_source).not_to be_nil
          expect(target_weights_source.rolled_up_weight).to eq(weights_source.rolled_up_weight)
          expect(target_weights_source.rolled_up_completed_weight).to eq(weights_source.rolled_up_completed_weight)
        end
      end
    end
  end

  describe "post_move_cleanup" do
    context "when work item does not have weights source" do
      it "does not copy the weight data" do
        expect { callback.post_move_cleanup }.not_to change { WorkItems::WeightsSource.count }
      end
    end

    context "when work item has weights source" do
      let!(:weights_source) { create(:work_item_weights_source, work_item: work_item) }

      it "destroys the weights source" do
        expect { callback.post_move_cleanup }.to change { WorkItems::WeightsSource.count }.by(-1)
      end
    end
  end
end
