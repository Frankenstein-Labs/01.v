# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::NonWidgets::PendingEscalations, feature_category: :incident_management do
  let_it_be(:current_user) { create(:user) }
  let_it_be_with_reload(:work_item) { create(:work_item, :incident) }
  let_it_be_with_reload(:target_work_item) { create(:work_item) }

  let_it_be(:pending_escalations) do
    project = work_item.project
    policy = create(:incident_management_escalation_policy, project: project)
    create_list(:incident_management_pending_issue_escalation, 3, issue: work_item, project: project, policy: policy)
  end

  let(:params) { { operation: :move } }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: params
    )
  end

  describe '#after_save_commit' do
    context 'when cloning work item' do
      let(:params) { { operation: :clone } }

      it 'does not copy pending escalations to target item' do
        expect { callback.after_save_commit }.not_to change { target_work_item.pending_escalations.count }
      end

      it 'does not remove pending escalations from original item' do
        expect { callback.after_save_commit }.not_to change { work_item.pending_escalations.count }
      end
    end

    context 'when moving work item' do
      it 'does not copy pending escalations to target item' do
        expect { callback.after_save_commit }.not_to change { target_work_item.pending_escalations.count }
      end

      it 'removes pending escalations from original item' do
        expect { callback.after_save_commit }.to change { work_item.pending_escalations.count }.from(3).to(0)
      end
    end
  end
end
