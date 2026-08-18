# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemVersionDependency, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:dependency).required.inverse_of(:dependents) }
    it { is_expected.to belong_to(:ai_catalog_item_version).required }
  end

  describe 'validations' do
    subject { create(:ai_catalog_item_version_dependency) }

    it { is_expected.to validate_uniqueness_of(:dependency_id).scoped_to(:ai_catalog_item_version_id) }
  end
end
