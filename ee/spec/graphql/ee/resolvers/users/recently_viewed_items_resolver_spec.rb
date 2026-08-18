# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Users::RecentlyViewedItemsResolver, feature_category: :notifications do
  include GraphqlHelpers

  describe '#resolve with EE features' do
    let_it_be(:user) { create(:user) }

    it 'does not include RecentEpics separately' do
      expect(Gitlab::Search::RecentEpics).not_to receive(:new)
      resolve_recent_items(current_user: user)
    end
  end

  def resolve_recent_items(current_user:)
    resolve(described_class, obj: current_user, ctx: { current_user: current_user })
  end
end
