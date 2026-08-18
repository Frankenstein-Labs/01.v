# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Notes::AvailableQuickActionsResolver, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, :private, developers: user) }
  let_it_be(:work_item) { create(:work_item, :group_level, namespace: group) }

  let(:current_user) { user }

  subject(:resolved) { resolve(described_class, obj: work_item, ctx: { current_user: current_user }) }

  context 'when the group is licensed for group-level work items' do
    before do
      stub_licensed_features(epics: true)
    end

    it 'resolves the commands against the group container' do
      names = resolved.map { |command| command[:name] }

      expect(names).to include(:close, :title, :todo)
    end
  end

  context 'when the group is not licensed for group-level work items' do
    before do
      stub_licensed_features(epics: false)
    end

    it { is_expected.to eq([]) }
  end
end
