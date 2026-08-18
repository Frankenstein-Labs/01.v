# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ReindexingSubtask, type: :model, feature_category: :global_search do
  describe 'relations' do
    it { is_expected.to belong_to(:elastic_reindexing_task) }
    it { is_expected.to have_many(:slices) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:index_name_from) }
    it { is_expected.to validate_presence_of(:index_name_to) }
  end
end
