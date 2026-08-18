# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Banzai::Filter::References::WikiPageReferenceFilter, feature_category: :wiki do
  include FilterSpecHelper

  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  # `freeze: false` is kept here because this `let_it_be` subject is not an
  # ActiveRecord record (or memoizes internal state); freezing raises
  # FrozenError and reload/refind are no-ops on it. Keep as-is (see
  # gitlab-org/gitlab#602925).
  let_it_be(:wiki, freeze: false) { GroupWiki.new(group, user) }
  let_it_be(:wiki_page) { create(:wiki_page, wiki: wiki, title: 'nested/twice/start-page') }
  let_it_be_with_reload(:cross_group) { create(:group) }
  # `freeze: false` is kept here because this `let_it_be` subject is not an
  # ActiveRecord record (or memoizes internal state); freezing raises
  # FrozenError and reload/refind are no-ops on it. Keep as-is (see
  # gitlab-org/gitlab#602925).
  let_it_be(:cross_wiki, freeze: false) { GroupWiki.new(cross_group, user) }
  let_it_be_with_reload(:cross_wiki_page) { create(:wiki_page, wiki: cross_wiki, title: 'nested/twice/start-page') }

  let(:context) { { project: nil, group: group } }

  shared_examples 'a wiki page reference' do
    it_behaves_like 'a reference containing an element node'

    it 'links to a valid reference' do
      doc = reference_filter("Fixed #{written_reference}", context)

      expect(doc.css('a').first.attr('href')).to eq wiki_page_url
    end

    it 'links with adjacent text' do
      doc = reference_filter("Fixed (#{written_reference}.)", context)

      expect(doc.text).to match(%r{^Fixed \(.*\.\)})
    end

    it 'includes a title attribute' do
      doc = reference_filter("Created #{written_reference}", context)

      expect(doc.css('a').first.attr('title')).to eq wiki_page.title
    end

    it 'escapes the title attribute' do
      allow_next_instance_of(GroupWiki) do |instance|
        allow(instance).to receive(:title).and_return(%("></a>whatever<a title="))
      end

      doc = reference_filter("Created #{written_reference}", context)

      expect(doc.text).not_to include 'whatever'
    end

    it 'renders non-HTML tooltips' do
      doc = reference_filter("Created #{written_reference}", context)

      expect(doc.at_css('a')).not_to have_attribute('data-html')
    end

    it 'includes default classes' do
      doc = reference_filter("Created #{written_reference}", context)

      expect(doc.css('a').first.attr('class')).to eq 'gfm gfm-wiki_page has-tooltip'
    end

    it 'includes a data-wiki-page attribute' do
      doc = reference_filter("See #{written_reference}", context)
      link = doc.css('a').first

      expect(link).to have_attribute('data-wiki-page')
      expect(link.attr('data-wiki-page')).to eq wiki_page.slug
    end

    it 'includes a data-original attribute' do
      doc = reference_filter("See #{written_reference}", context)
      link = doc.css('a').first

      expect(link).to have_attribute('data-original')
      expect(link.attr('data-original')).to eq inner_text
    end

    it 'does not escape the data-original attribute' do
      skip if written_reference.start_with?('<a')

      inner_html = 'element <code>node</code> inside'
      doc = reference_filter(%(<a href="#{written_reference}">#{inner_html}</a>), context)

      expect(doc.children.first.children.first.attr('data-original')).to eq inner_html
    end

    it 'does not process links containing issue numbers followed by text' do
      href = "#{written_reference}st"
      doc = reference_filter("<a href='#{href}'></a>", context)
      link = doc.css('a').first.attr('href')

      expect(link).to eq(href)
    end
  end

  context 'when group level wiki page URL reference' do
    let_it_be(:wiki_page_link_reference)  { urls.group_wiki_url(group, wiki_page) }
    let_it_be(:wiki_page_url)             { wiki_page_link_reference }
    let_it_be(:reference)                 { wiki_page_url }
    let_it_be(:written_reference)         { reference }
    let_it_be(:inner_text)                { written_reference }

    it_behaves_like 'a wiki page reference'
  end

  context 'when group level wiki page full reference' do
    let_it_be(:wiki_page_link_reference)  { urls.group_wiki_url(group, wiki_page) }
    let_it_be(:wiki_page_url)             { wiki_page_link_reference }
    let_it_be(:reference)                 { wiki_page.to_reference(full: true) }
    let_it_be(:written_reference)         { reference }
    let_it_be(:inner_text)                { written_reference }

    it_behaves_like 'a wiki page reference'
  end

  context 'on [wiki_page:XXX] reference' do
    let_it_be(:written_reference)         { "[wiki_page:#{wiki_page.slug}]" }
    let_it_be(:reference)                 { written_reference }
    let_it_be(:inner_text)                { written_reference }
    let_it_be(:wiki_page_link_reference)  { urls.group_wiki_url(group, wiki_page) }
    let_it_be(:wiki_page_url)             { wiki_page_link_reference }

    it_behaves_like 'a wiki page reference'
  end

  context 'on cross group [wiki_page:group/path:slug] reference' do
    let_it_be(:wiki_page_link_reference)  { urls.group_wiki_url(cross_group, wiki_page) }
    let_it_be(:wiki_page_url)             { wiki_page_link_reference }
    let_it_be(:written_reference)         do
      "[wiki_page:#{cross_group.full_path}:#{cross_wiki_page.slug}]"
    end

    let_it_be(:reference)                 { written_reference }
    let_it_be(:inner_text)                { written_reference }

    it_behaves_like 'a wiki page reference'
  end

  # Example:
  #   "See http://localhost/cross-namespace/cross-group/-/wikis/foobar"
  context 'when cross-group URL reference' do
    let_it_be(:wiki_page_link_reference)  { urls.group_wiki_url(cross_group, wiki_page) }
    let_it_be(:wiki_page_url)             { wiki_page_link_reference }
    let_it_be(:reference)                 { wiki_page_url }
    let_it_be(:written_reference)         { reference }
    let_it_be(:inner_text)                { written_reference }

    it_behaves_like 'a wiki page reference'

    it 'includes a data-group attribute' do
      doc = reference_filter("Created #{written_reference}", context)
      link = doc.css('a').first

      expect(link).to have_attribute('data-group')
      expect(link.attr('data-group')).to eq cross_group.id.to_s
    end
  end
end
