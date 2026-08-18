# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Wikis::WikiPageResolver, feature_category: :wiki do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }

    let(:slug) { wiki_page_meta.canonical_slug }

    context 'for group wikis' do
      let_it_be(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }

      subject(:resolved_wiki_page) do
        resolve_wiki_page('slug' => slug, 'namespace_id' => global_id_of(group))
      end

      it { is_expected.to eq(wiki_page_meta) }

      context 'when page does not exist' do
        let(:slug) { 'foobar' }

        it { is_expected.to be_nil }
      end

      context 'when page exists, but does not have a meta record' do
        it 'creates a new WikiPage::Meta record' do
          wiki_page_meta.delete

          expect { resolved_wiki_page }.to change { WikiPage::Meta.count }.by(1)
        end
      end
    end
  end

  private

  def resolve_wiki_page(args = {})
    resolve(described_class, args: args, ctx: { current_user: user })
  end
end
