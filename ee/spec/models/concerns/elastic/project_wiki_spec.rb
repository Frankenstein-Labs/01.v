# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectWiki, :elastic, :sidekiq_inline, feature_category: :global_search do
  let_it_be_with_reload(:project) { create(:project, :wiki_repo, :public) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)

    project.wiki.create_page('index_page', 'Bla bla term1')
    project.wiki.create_page('omega_page', 'Bla bla term2')
    project.wiki.index_wiki_blobs

    ensure_elasticsearch_index!
  end

  describe '#use_elasticsearch?' do
    it 'delegates to Project#use_elasticsearch?' do
      expect(project).to receive(:use_elasticsearch?)

      project.wiki.use_elasticsearch?
    end
  end

  it 'searches wiki page' do
    results = project.wiki.elastic_search('term1', type: 'wiki_blob', options: { search_level: :global })
    expect(results[:wiki_blobs][:total_count]).to eq(1)

    results = project.wiki.elastic_search('term1 | term2', type: 'wiki_blob', options: { search_level: :global })
    expect(results[:wiki_blobs][:total_count]).to eq(2)
  end

  it 'indexes using ElasticWikiIndexerWorker' do
    expect(ElasticWikiIndexerWorker).to receive(:perform_async).with(project.id, project.class.name)

    project.wiki.index_wiki_blobs
  end

  it 'can delete wiki pages' do
    results = project.wiki.elastic_search('term2', type: 'wiki_blob', options: { search_level: :global })
    expect(results[:wiki_blobs][:total_count]).to eq(1)

    Sidekiq::Testing.inline! do
      project.wiki.find_page('omega_page').delete

      expect_next_instance_of(Search::Elastic::Indexer) do |indexer|
        expect(indexer).to receive(:run).and_call_original
      end

      project.wiki.index_wiki_blobs

      ensure_elasticsearch_index!
    end

    results = project.wiki.elastic_search('term2', type: 'wiki_blob', options: { search_level: :global })
    expect(results[:wiki_blobs][:total_count]).to eq(0)
  end
end
