# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EpicUserMention, feature_category: :team_planning do
  describe 'associations' do
    it { is_expected.to belong_to(:epic) }
    it { is_expected.to belong_to(:note) }
    it { is_expected.to belong_to(:group) }
  end

  it_behaves_like 'has user mentions' do
    let_it_be(:mentionable_key) { 'epic_id' }
    let_it_be(:mentionable) { create(:epic) }
  end
end
