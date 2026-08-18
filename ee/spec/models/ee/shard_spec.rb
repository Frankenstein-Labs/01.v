# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Shard, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to have_many(:group_wiki_repositories).dependent(:restrict_with_exception) }
  end

  describe 'deletion restriction' do
    it 'cannot be deleted while it has associated group_wiki_repositories' do
      group_wiki_repository = create(:group_wiki_repository)
      shard = group_wiki_repository.shard

      expect { shard.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end

    it 'can be deleted when it has no associated group_wiki_repositories' do
      shard = create(:shard, name: 'test-storage')

      expect { shard.destroy! }.not_to raise_error
    end
  end
end
