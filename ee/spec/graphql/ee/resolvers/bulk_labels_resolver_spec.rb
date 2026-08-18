# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::BulkLabelsResolver, feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be(:group) { create(:group) }
  let_it_be(:epic) { create(:epic, group: group) }

  let_it_be(:label_a) { create(:group_label, group: group, title: 'A') }
  let_it_be(:label_b) { create(:group_label, group: group, title: 'B') }
  let_it_be(:label_c) { create(:group_label, group: group, title: 'C') }
  let_it_be(:label_d) { create(:group_label, group: group, title: 'D') }

  before do
    epic.labels << [label_b, label_c]
    epic.work_item.labels << [label_a, label_d]
  end

  describe '#resolve' do
    subject(:execute) { batch_sync { resolve(described_class, obj: epic.work_item, args: {}, ctx: context) } }

    let(:context) { GraphQL::Query::Context.new(query: query_double(schema: nil), values: { current_user: user }) }

    it 'returns the labels sorted by title' do
      expect(execute.map(&:title)).to eq(%w[A B C D])
    end
  end
end
