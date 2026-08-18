# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::API::Entities::AwardEmoji, feature_category: :portfolio_management do
  subject(:entity) { described_class.new(award_emoji, options).as_json }

  let_it_be(:user) { create(:user) }
  let_it_be(:issue) { create(:issue) }
  let_it_be(:award_emoji) { create(:award_emoji, awardable: issue, user: user) }

  let(:options) { {} }

  it 'returns original awardable fields without work item id' do
    expect(entity[:awardable_type]).to eq('Issue')
    expect(entity[:awardable_id]).to eq(issue.id)
    expect(entity[:awardable_work_item_id]).to be_nil
  end
end
