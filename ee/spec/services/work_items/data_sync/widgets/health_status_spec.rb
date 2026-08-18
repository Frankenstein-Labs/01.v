# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::HealthStatus, feature_category: :team_planning do
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project, health_status: :on_track) }
  let_it_be_with_reload(:target_work_item) { create(:work_item, project: project, health_status: :at_risk) }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: {}
    )
  end

  describe '#before_create' do
    context 'when health status feature is not available' do
      before do
        stub_licensed_features(issuable_health_status: false)
      end

      it 'does not copy health_status data' do
        expect { callback.before_create }.not_to change { target_work_item.health_status }
      end
    end

    context 'when health status feature is available' do
      before do
        stub_licensed_features(issuable_health_status: true)
      end

      context 'when target work item does not have health_status widget' do
        before do
          allow(target_work_item).to receive(:get_widget).with(:health_status).and_return(false)
        end

        it 'does not copy health_status data' do
          expect { callback.before_create }.not_to change { target_work_item.health_status }
        end
      end

      context 'when target work item has health_status widget' do
        before do
          allow(target_work_item).to receive(:get_widget).with(:health_status).and_return(true)
        end

        it 'copies the health_status data' do
          expect { callback.before_create }.to change { target_work_item.health_status }.from("at_risk").to(
            work_item.health_status
          )
        end

        context 'and original work item does not have an health_status set' do
          before do
            work_item.update!(health_status: nil)
          end

          it 'copies the health_status data' do
            expect { callback.before_create }.to change { target_work_item.health_status }.from("at_risk").to(
              work_item.health_status
            )
          end
        end
      end
    end
  end
end
