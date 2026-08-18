# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::SnippetSearchResults, :elastic_delete_by_query, :sidekiq_inline,
  feature_category: :global_search do
  let_it_be(:snippet) do
    create(:personal_snippet, title: 'foo bar foo cow foo moon', description: 'foo brown foo dog foo jump')
  end

  let(:results) { described_class.new(snippet.author, 'foo') }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    Elastic::ProcessInitialBookkeepingService.track!(snippet)
    ensure_elasticsearch_index!
  end

  describe 'pagination' do
    let_it_be(:snippet2) do
      create(:personal_snippet, author: snippet.author, title: 'foo once', description: 'content')
    end

    before do
      Elastic::ProcessInitialBookkeepingService.track!(snippet2)
      ensure_elasticsearch_index!
    end

    it 'properly paginates results' do
      expect(results.objects('snippet_titles', page: 1, per_page: 1).size).to eq(1)
      expect(results.objects('snippet_titles', page: 2, per_page: 1).size).to eq(1)
    end

    it 'returns the correct number of results for one page' do
      expect(results.objects('snippet_titles', page: 1, per_page: 2)).to match_array([snippet, snippet2])
    end
  end

  describe '#snippet_titles_count' do
    it 'returns the amount of matched snippet titles' do
      expect(results.snippet_titles_count).to eq(1)
    end
  end

  describe '#formatted_count' do
    using RSpec::Parameterized::TableSyntax

    where(:value, :expected) do
      1     | '1'
      9999  | '9,999'
      10000 | '10,000+'
      20000 | '10,000+'
      0     | '0'
      nil   | '0'
    end

    with_them do
      it 'returns the expected formatted count limited and delimited' do
        expect(results).to receive(:snippet_titles_count).and_return(value)
        expect(results.formatted_count('snippets')).to eq(expected)
      end
    end
  end

  describe '#highlight_map' do
    it 'returns the expected highlight map' do
      highlight = 'test <span class="gl-text-default gl-font-bold">highlight</span>'
      expect(results).to receive(:snippet_titles).and_return([{ _source: { id: 1 }, highlight: highlight }])
      expect(results.highlight_map('snippet_titles')).to eq({ 1 => highlight })
    end
  end

  context 'when user is not author' do
    let(:results) { described_class.new(create(:user), 'foo') }

    it 'returns nothing' do
      expect(results.snippet_titles_count).to eq(0)
    end
  end

  context 'when user is nil' do
    let(:results) { described_class.new(nil, 'foo') }

    it 'returns nothing' do
      expect(results.snippet_titles_count).to eq(0)
    end

    context 'when snippet is public' do
      let(:snippet) { create(:personal_snippet, :public, title: 'foo', description: 'foo') }

      it 'returns public snippet' do
        expect(results.snippet_titles_count).to eq(1)
      end
    end
  end

  context 'when user has read_all_resources' do
    include_context 'custom session'

    let(:user) { create(:admin) }
    let(:results) { described_class.new(user, 'foo') }

    context 'with admin mode disabled' do
      it 'returns nothing' do
        expect(results.snippet_titles_count).to eq(0)
      end
    end

    context 'with admin mode enabled', :enable_admin_mode do
      it 'returns matched snippets' do
        expect(results.snippet_titles_count).to eq(1)
      end
    end
  end
end
