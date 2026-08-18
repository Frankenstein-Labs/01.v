# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::ReorderService, feature_category: :team_planning do
  let_it_be(:group)   { create(:group) }
  let_it_be(:user)    { create_default(:user, developer_of: group) }
  let_it_be(:project) { create(:project, namespace: group) }

  describe '#execute' do
    let_it_be(:item1) { create(:work_item, :issue, project: project, relative_position: 10) }
    let_it_be(:item2) { create(:work_item, :issue, project: project, relative_position: 20) }
    let_it_be(:non_project_work_item, freeze: false) do
      create(:work_item, :group_level, namespace: group, relative_position: 10)
    end

    let(:work_item) { non_project_work_item }
    let(:params) { {} }

    subject(:service_result) do
      described_class
        .new(current_user: user, params: params)
        .execute(work_item)
    end

    context 'with epics enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when ordering work items in a group' do
        context 'with a non-project level work item' do
          let(:params) { { move_after_id: item1.id, move_before_id: item2.id } }

          it 'reorders correctly' do
            expect { service_result }
              .to change { non_project_work_item.relative_position }
              .to be_between(item1.relative_position, item2.relative_position)
          end
        end
      end
    end
  end
end
