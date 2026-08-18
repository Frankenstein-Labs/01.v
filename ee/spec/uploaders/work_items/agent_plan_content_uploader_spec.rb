# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::AgentPlanContentUploader, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item) }
  let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item) }

  let(:uploader) { described_class.new(agent_plan) }

  subject { uploader }

  it_behaves_like "builds correct paths",
    store_dir: %r{\A\h{2}/\h{2}/\h{64}/work_item_agent_plans/\d+\z},
    cache_dir: %r{/agent_plan_content/tmp/cache\z},
    work_dir: %r{/agent_plan_content/tmp/work\z}

  describe '#filename' do
    it 'returns work_item_id.json' do
      expect(uploader.filename).to eq("#{agent_plan.work_item_id}.json")
    end
  end

  describe '#store_dir' do
    context 'when namespace_id differs' do
      let_it_be(:other_work_item) { create(:work_item) }
      let_it_be(:other_agent_plan) { create(:work_item_agent_plan, work_item: other_work_item) }

      let(:other_uploader) { described_class.new(other_agent_plan) }

      it 'produces different paths for different namespaces' do
        expect(uploader.store_dir.to_s).not_to eq(other_uploader.store_dir.to_s)
      end
    end
  end
end
