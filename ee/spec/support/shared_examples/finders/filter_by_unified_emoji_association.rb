# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'filter by unified emoji association' do
  let(:params) { filtering_params.merge(group_id: group) }

  subject do
    described_class.new(user, params).execute
  end

  before_all do
    create(:award_emoji, name: AwardEmoji::THUMBS_UP, awardable: object1, user: user)
    create(:award_emoji, name: 'eyes', awardable: object1.sync_object, user: user)
    create(:award_emoji, name: 'rocket', awardable: object2.sync_object, user: user)
    create(:award_emoji, name: 'eyes', awardable: object3, user: user)
  end

  context 'when filtering by emoji name' do
    let(:filtering_params) { { my_reaction_emoji: 'eyes' } }

    it { is_expected.to contain_exactly(object1, object3) }
  end

  context 'when filterint by negated emoji name' do
    let(:filtering_params) { { not: { my_reaction_emoji: 'eyes' } } }

    it { is_expected.to contain_exactly(object2, object4) }
  end

  context 'when filtering by name and negated name' do
    let(:filtering_params) do
      {
        my_reaction_emoji: 'rocket',
        not: { my_reaction_emoji: 'eyes' }
      }
    end

    it { is_expected.to contain_exactly(object2) }
  end

  context 'when filtering by any emoji' do
    let(:filtering_params) { { my_reaction_emoji: 'any' } }

    it { is_expected.to contain_exactly(object1, object2, object3) }
  end

  context 'when filtering by none emoji' do
    let(:filtering_params) { { my_reaction_emoji: 'none' } }

    it { is_expected.to contain_exactly(object4) }
  end

  context 'when filtering by any emoji and negated name' do
    let(:filtering_params) do
      {
        my_reaction_emoji: 'any',
        not: { my_reaction_emoji: 'eyes' }
      }
    end

    it { is_expected.to contain_exactly(object2) }
  end
end
