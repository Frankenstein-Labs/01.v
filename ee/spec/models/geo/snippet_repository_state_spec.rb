# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::SnippetRepositoryState, :geo, type: :model, feature_category: :geo_replication do
  describe 'associations' do
    it { is_expected.to belong_to(:snippet_repository).inverse_of(:snippet_repository_state) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:snippet_repository) }
  end
end
