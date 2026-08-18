# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WorkItems::Widgets::LinkedItems, feature_category: :portfolio_management do
  describe '.quick_action_commands' do
    specify do
      expect(described_class.quick_action_commands).to contain_exactly(:blocks, :blocked_by, :relate, :unlink)
    end
  end

  describe '.sorting_keys' do
    specify do
      expect(described_class.sorting_keys.keys).to contain_exactly(:blocking_issues_asc, :blocking_issues_desc)
    end
  end
end
