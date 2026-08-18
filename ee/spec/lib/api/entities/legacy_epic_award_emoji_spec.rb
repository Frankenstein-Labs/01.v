# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::LegacyEpicAwardEmoji, feature_category: :portfolio_management do
  subject(:entity) { described_class.new(award_emoji, options).as_json }

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be_with_reload(:award_emoji) { create(:award_emoji, awardable: epic, user: user) }

  let(:options) { { epic: epic } }

  it 'returns epic-flavored response with work item id derived from epic' do
    expect(entity[:awardable_type]).to eq('Epic')
    expect(entity[:awardable_id]).to eq(epic.id)
    expect(entity[:awardable_work_item_id]).to eq(epic.issue_id)
  end

  context 'when award emoji points to the work item (post-backfill)' do
    before do
      award_emoji.update_columns(awardable_type: 'Issue', awardable_id: epic.issue_id)
    end

    it 'still returns epic-flavored response' do
      expect(entity[:awardable_type]).to eq('Epic')
      expect(entity[:awardable_id]).to eq(epic.id)
      expect(entity[:awardable_work_item_id]).to eq(epic.issue_id)
    end
  end
end
