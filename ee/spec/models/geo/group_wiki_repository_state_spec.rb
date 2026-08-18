# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::GroupWikiRepositoryState, :geo, type: :model, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:group_wiki_repository).inverse_of(:group_wiki_repository_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:group_wiki_repository) }
  end
end
