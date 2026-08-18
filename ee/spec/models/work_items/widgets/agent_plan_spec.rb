# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::AgentPlan, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item) }
  let_it_be(:agent_plan) { create(:work_item_agent_plan, work_item: work_item, content: '**plan**') }

  describe '.type' do
    subject { described_class.type }

    it { is_expected.to eq(:agent_plan) }
  end

  describe '.required_user_ability' do
    it { expect(described_class.required_user_ability).to eq(:update_work_item) }
  end

  describe '.api_symbol' do
    subject { described_class.api_symbol }

    it { is_expected.to eq(:agent_plan_widget) }
  end

  describe '#content' do
    subject { described_class.new(work_item).content }

    it { is_expected.to eq('**plan**') }

    context 'when agent plan does not exist' do
      let_it_be(:work_item_without_plan) { create(:work_item) }

      subject { described_class.new(work_item_without_plan).content }

      it { is_expected.to be_nil }
    end
  end

  describe '#content_html' do
    subject { described_class.new(work_item).content_html }

    it { is_expected.to be_present }

    context 'when agent plan does not exist' do
      let_it_be(:work_item_without_plan) { create(:work_item) }

      subject { described_class.new(work_item_without_plan).content_html }

      it { is_expected.to be_nil }
    end
  end
end
