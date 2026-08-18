# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TypesFramework::SystemDefined::Definitions::Epic, feature_category: :team_planning do
  describe '.widgets' do
    it 'returns the correct list of widgets' do
      expected_widgets = %w[
        ai_session
        assignees
        award_emoji
        color
        current_user_todos
        custom_fields
        description
        health_status
        hierarchy
        labels
        linked_items
        milestone
        notes
        notifications
        participants
        start_and_due_date
        verification_status
        time_tracking
        weight
      ]

      expect(described_class.widgets).to match_array(expected_widgets)
    end
  end

  describe '.widget_options' do
    it 'returns the correct widget options hash' do
      expected_options = {
        hierarchy: { propagates_milestone: true, auto_expand_tree_on_move: true },
        start_and_due_date: { can_roll_up: true }
      }

      expect(described_class.widget_options).to eq(expected_options)
    end
  end

  describe '.configuration' do
    it 'returns the correct configuration hash' do
      expected_configuration = {
        id: 8,
        name: 'Epic',
        base_type: 'epic',
        icon_name: "work-item-epic"
      }

      expect(described_class.configuration).to eq(expected_configuration)
    end
  end

  describe '.license_name' do
    it 'returns :epics' do
      expect(described_class.license_name).to eq(:epics)
    end
  end

  describe '.licenses_for_parent' do
    it 'returns the correct licenses for parent types' do
      expected_licenses = { 'epic' => :subepics }

      expect(described_class.licenses_for_parent).to eq(expected_licenses)
    end
  end

  describe '.licenses_for_child' do
    it 'returns the correct licenses for child types' do
      expected_licenses = { 'epic' => :subepics, 'issue' => :epics }

      expect(described_class.licenses_for_child).to eq(expected_licenses)
    end
  end
end
