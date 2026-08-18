# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Wiki::ElasticDeleteGroupWikiWorker, feature_category: :global_search do
  describe '#perform', :elastic, :sidekiq_inline do
    # `freeze: false` is required here: GroupWiki is a PORO that memoizes
    # repository/page state; `deep_freeze` raises FrozenError. Keep the
    # opt-out (see gitlab-org/gitlab#602925).
    let_it_be(:wiki, freeze: false) { create(:group_wiki) }
    # `freeze: false` is required here: GroupWiki is a PORO that memoizes
    # repository/page state; `deep_freeze` raises FrozenError. Keep the
    # opt-out (see gitlab-org/gitlab#602925).
    let_it_be(:wiki2, freeze: false) { create(:group_wiki) }
    let(:project_wiki) { project.wiki }
    let(:group) { wiki.container }
    let(:group2) { wiki2.container }
    let_it_be_with_reload(:project) { create(:project, :wiki_repo) }

    subject(:worker) { described_class.new }

    it 'is a pause_control worker' do
      expect(described_class.get_pause_control).to eq(:advanced_search)
    end

    context 'when elasticsearch_indexing is false' do
      # `freeze: false` is required here: Search::Elastic::Helper is a PORO that memoizes
      # repository/page state; `deep_freeze` raises FrozenError. Keep the
      # opt-out (see gitlab-org/gitlab#602925).
      let_it_be(:helper, freeze: false) { Search::Elastic::Helper.default }

      before do
        stub_ee_application_setting(elasticsearch_indexing: false)

        allow(Search::Elastic::Helper).to receive(:default).and_return(helper)
      end

      it 'does nothing' do
        expect(helper).not_to receive(:remove_wikis_from_the_standalone_index)

        worker.perform(group.id)
      end
    end

    context 'when elasticsearch_indexing is true' do
      before do
        stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
        [wiki, wiki2, project_wiki].each.with_index do |wiki, idx|
          wiki.create_page("index_page#{idx}", 'Bla bla term')
          wiki.index_wiki_blobs
        end
        ensure_elasticsearch_index!
      end

      it_behaves_like 'an idempotent worker' do
        let(:job_args) { [group.id] }

        it 'removes all the wikis for the passed group' do
          expect(items_in_index(Elastic::Latest::WikiConfig.index_name, 'rid')).to include("wiki_group_#{group.id}")

          worker.perform(group.id)

          refresh_index!

          results = items_in_index(Elastic::Latest::WikiConfig.index_name, 'rid')
          expect(results).not_to include("wiki_group_#{group.id}")
          expect(results).to include("wiki_group_#{group2.id}")
          expect(results).to include("wiki_project_#{project.id}")
        end
      end
    end
  end
end
