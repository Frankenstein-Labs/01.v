# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::Iteration, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence, group: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project, iteration: iteration) }
  let_it_be_with_reload(:target_work_item) { create(:work_item, project: project) }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: {}
    )
  end

  before do
    stub_licensed_features(iterations: true)
  end

  describe '#before_create' do
    context 'when target work item does not have iteration widget' do
      before do
        allow(target_work_item).to receive(:get_widget).with(:iteration).and_return(false)
      end

      it 'does not copy iteration data' do
        expect { callback.before_create }.not_to change { target_work_item.iteration }
      end
    end

    context 'when user cannot read iteration widget' do
      let(:current_user) { create(:user) }

      it 'does not copy iteration data' do
        expect { callback.before_create }.not_to change { target_work_item.iteration }
      end
    end

    context 'when target work item has iteration widget' do
      context 'and original work item does not have an iteration set' do
        before do
          work_item.update_column(:sprint_id, nil)
        end

        it 'does not copy iteration data' do
          expect { callback.before_create }.not_to change { target_work_item.iteration }
        end
      end

      context 'and is within same project as original work item' do
        it 'copies the iteration data' do
          expect { callback.before_create }.to change { target_work_item.iteration }.from(nil).to(iteration)
        end
      end

      context 'and is within same hierarchy as original work item' do
        let_it_be(:project) { create(:project, group: group) }

        it 'copies the iteration data' do
          expect { callback.before_create }.to change { target_work_item.iteration }.from(nil).to(iteration)
        end
      end

      context 'and is within different hierarchy as original work item' do
        let_it_be(:project) { create(:project) }
        let_it_be_with_reload(:target_work_item) { create(:work_item, project: project) }

        it 'does not copy iteration data' do
          expect { callback.before_create }.not_to change { target_work_item.iteration }
        end
      end
    end
  end
end
