# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::SearchResults, 'notes', feature_category: :global_search do
  let(:query) { 'hello world' }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public, :repository, :wiki_repo) }

  before do
    stub_ee_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
  end

  describe 'notes', :elastic_delete_by_query do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issue) { create(:issue, project: project, title: 'Hello') }
    let_it_be(:note_1) { create(:note, noteable: issue, project: project, note: 'foo bar') }
    let_it_be(:note_2) { create(:note_on_issue, noteable: issue, project: project, note: 'foo baz') }
    let_it_be(:note_3) { create(:note_on_issue, noteable: issue, project: project, note: 'bar bar') }

    before do
      ::Elastic::ProcessInitialBookkeepingService.backfill_projects!(project)
      ensure_elasticsearch_index!
    end

    it_behaves_like 'a paginated object', 'notes'

    it 'lists found notes' do
      results = described_class.new(user, 'foo')
      notes = results.objects('notes')

      expect(notes).to contain_exactly(note_1, note_2)
      expect(results.notes_count).to eq 2
    end

    context 'when comment has some code snippet' do
      before do
        code_examples.values.uniq.each do |note|
          sha = Digest::SHA256.hexdigest(note)
          create(:note_on_issue, noteable: issue, project: project, commit_id: sha, note: note)
        end
        ensure_elasticsearch_index!
      end

      include_context 'with code examples' do
        it 'finds all examples' do
          code_examples.each do |query, description|
            sha = Digest::SHA256.hexdigest(description)
            notes = described_class.new(user, query).objects('notes')
            expect(notes.map(&:commit_id)).to include(sha)
          end
        end
      end
    end

    it 'returns empty list when notes are not found' do
      results = described_class.new(user, 'security')

      expect(results.objects('notes')).to be_empty
      expect(results.notes_count).to eq 0
    end
  end
end
