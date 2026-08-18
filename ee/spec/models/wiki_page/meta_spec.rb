# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPage::Meta, feature_category: :wiki do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:other_group) { create(:group, :private) }

  before do
    stub_licensed_features(group_wikis: true)
  end

  include_examples 'creating wiki page meta record examples' do
    let(:container) { group }
    let(:other_container) { other_group }
  end

  describe '#resource_parent' do
    subject(:meta) { described_class.new(title: 'some title', namespace: group) }

    it 'returns container' do
      expect(meta.resource_parent).to eq(group)
    end
  end

  describe '#gfm_reference' do
    context 'with group container' do
      it 'returns class name without reference' do
        meta = create(:wiki_page_meta, :for_wiki_page, container: group)

        expect(meta.gfm_reference)
          .to eq("group wiki page [wiki_page:#{meta.container.full_path}:#{meta.wiki_page.slug}]")
      end
    end
  end
end
