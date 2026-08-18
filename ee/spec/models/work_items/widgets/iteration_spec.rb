# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Iteration, feature_category: :team_planning do
  let_it_be(:work_item) { create(:work_item, :issue) }

  describe '#iteration' do
    subject { described_class.new(work_item).iteration }

    it { is_expected.to eq(work_item.iteration) }
  end

  describe '.quick_action_params' do
    subject { described_class.quick_action_params }

    it { is_expected.to match_array([:iteration]) }
  end

  describe '.quick_action_commands' do
    subject { described_class.quick_action_commands }

    it { is_expected.to match_array([:iteration, :remove_iteration]) }
  end
end
