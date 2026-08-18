# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'wikis', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:project_1) { create(:project, :public, :repository, :wiki_repo) }
  let_it_be(:project_2) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'wikis', :elastic_delete_by_query, :sidekiq_inline do
    let(:results) { described_class.new(user, 'term') }

    subject(:wiki_blobs) { results.objects('wiki_blobs') }

    before do
      if project_1.wiki_enabled?
        project_1.wiki.create_page('index_page', 'term')
        project_1.wiki.index_wiki_blobs
      end

      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'wiki_blobs'

    it 'finds wiki blobs' do
      blobs = results.objects('wiki_blobs')

      expect(blobs.first.data).to include('term')
      expect(results.wiki_blobs_count).to eq 1
    end

    describe 'searches with various characters in wiki', :aggregate_failures do
      let_it_be(:page_prefix) { SecureRandom.hex(8) }

      before do
        code_examples.values.uniq.each do |page_content|
          page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}"
          project_1.wiki.create_page(page_title, page_content)
        end

        text_examples.values.uniq.each do |page_content|
          page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}"
          project_1.wiki.create_page(page_title, page_content)
        end

        project_1.wiki.index_wiki_blobs
        ensure_elasticsearch_index!
      end

      include_context 'with code examples' do
        it 'finds all examples in wiki' do
          code_examples.each do |search_term, page_content|
            page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}.md"
            expect(search_for(search_term)).to include(page_title), "failed to find #{search_term} in wiki"
          end
        end
      end

      include_context 'with text examples' do
        it 'finds all examples in wiki' do
          text_examples.each do |search_term, page_content|
            page_title = "#{page_prefix}-#{Digest::SHA256.hexdigest(page_content)}.md"
            expect(search_for(search_term)).to include(page_title), "failed to find #{search_term} in wiki"
          end
        end
      end

      def search_for(term)
        described_class.new(user, term).objects('wiki_blobs').map(&:path)
      end
    end
  end
end
