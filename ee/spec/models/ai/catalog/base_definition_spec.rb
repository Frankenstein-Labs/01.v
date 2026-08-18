# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::BaseDefinition, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be_with_reload(:item_version_1) { create(:ai_catalog_item_version, item: item, version: '1.0.0') }
  let_it_be(:item_version_2) { create(:ai_catalog_item_version, item: item, version: '1.1.0') }
  let_it_be(:version) { '1.0.0' }

  subject(:base_definition) { described_class.new(item, version) }

  before_all do
    item_version_1
    item_version_2
  end

  describe '#initialize' do
    it 'sets the item and version' do
      expect(base_definition.instance_variable_get(:@item)).to eq(item)
      expect(base_definition.instance_variable_get(:@version)).to eq(version)
    end
  end
end
