# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::AwardEmoji, feature_category: :team_planning do
  let_it_be(:user_developer) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:project_work_item) { create(:work_item, project: project) }
  let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group) }
  let(:expected_path) { "/groups/#{group.full_path}/-/custom_emoji/new" }

  before_all do
    group.add_developer(user_developer)
    project.add_developer(user_developer)
  end

  describe '#new_custom_emoji_path' do
    it 'returns the new custom emoji path for group-level work item' do
      expect(described_class.new(group_work_item).new_custom_emoji_path(user_developer)).to eq(expected_path)
    end

    it 'returns the new custom emoji path for project-level work item' do
      expect(described_class.new(project_work_item).new_custom_emoji_path(user_developer)).to eq(expected_path)
    end
  end
end
