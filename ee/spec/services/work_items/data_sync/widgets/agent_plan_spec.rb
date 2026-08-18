# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::Widgets::AgentPlan, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }

  let(:params) { {} }

  subject(:callback) do
    described_class.new(
      work_item: work_item, target_work_item: target_work_item, current_user: current_user, params: params
    )
  end

  describe '#after_save_commit' do
    let_it_be(:target_work_item) { create(:work_item) }

    context 'when source work item has no agent plan' do
      let_it_be(:work_item) { create(:work_item) }

      it 'does not create an agent plan on the target' do
        expect { callback.after_save_commit }.not_to change { ::WorkItems::AgentPlan.count }
      end
    end

    context 'when source work item has an agent plan' do
      let_it_be(:work_item) { create(:work_item) }
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, content: '**plan content**') }

      it 'creates an agent plan on the target work item' do
        expect { callback.after_save_commit }.to change { ::WorkItems::AgentPlan.count }.by(1)
      end

      it 'copies the content to the target agent plan' do
        callback.after_save_commit

        target_plan = target_work_item.reload.agent_plan
        expect(target_plan.content).to eq('**plan content**')
      end

      it 'renders markdown on the target agent plan' do
        callback.after_save_commit

        target_plan = target_work_item.reload.agent_plan
        doc = Nokogiri::HTML5.fragment(target_plan.content_html)
        expect(doc.at_css('strong')).to be_present
      end

      it 'copies ai_planning_enabled to the target agent plan' do
        callback.after_save_commit

        expect(target_work_item.reload.agent_plan.ai_planning_enabled).to be false
      end
    end

    context 'when source work item has an agent plan with ai_planning_enabled' do
      let_it_be(:work_item) { create(:work_item) }
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, ai_planning_enabled: true) }

      it 'copies ai_planning_enabled to the target agent plan' do
        callback.after_save_commit

        expect(target_work_item.reload.agent_plan.ai_planning_enabled).to be true
      end
    end

    context 'when source work item has an agent plan with a readiness_score' do
      let_it_be(:work_item) { create(:work_item) }
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, readiness_score: 75) }

      it 'copies readiness_score to the target agent plan' do
        callback.after_save_commit

        expect(target_work_item.reload.agent_plan.readiness_score).to eq(75)
      end
    end

    context 'when source work item has an agent plan with no readiness_score' do
      let_it_be(:work_item) { create(:work_item) }
      let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, readiness_score: nil) }

      it 'copies nil readiness_score to the target agent plan' do
        callback.after_save_commit

        expect(target_work_item.reload.agent_plan.readiness_score).to be_nil
      end
    end
  end

  describe '#post_move_cleanup' do
    let_it_be(:target_work_item) { create(:work_item) }

    context 'when source work item has no agent plan' do
      let_it_be(:work_item) { create(:work_item) }

      it 'does not raise' do
        expect { callback.post_move_cleanup }.not_to raise_error
      end
    end

    context 'when source work item has an agent plan' do
      let_it_be(:work_item) { create(:work_item) }

      before do
        create(:work_item_agent_plan, work_item: work_item, content: 'to be removed')
      end

      it 'destroys the source agent plan' do
        expect { callback.post_move_cleanup }.to change { ::WorkItems::AgentPlan.count }.by(-1)
      end
    end
  end
end
