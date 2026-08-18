# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Git::WikiPushService, feature_category: :source_code_management do
  include RepoHelpers

  let_it_be(:key_id, freeze: false) { create(:key, user: current_user).shell_id }
  let_it_be(:wiki, freeze: false) { create(:project_wiki) }
  let_it_be(:current_user, freeze: false) { wiki.container.first_owner }
  let_it_be(:repository, freeze: false) { wiki.repository }

  describe 'group behavior' do
    let(:post_received) { ::Gitlab::GitPostReceive.new(wiki.container, key_id, changes, {}) }

    before do
      allow(post_received).to receive(:identify).and_return(current_user)
    end

    context 'when elasticsearch is enabled' do
      before do
        allow(wiki.container).to receive(:use_elasticsearch?).and_return(true)
      end

      describe 'when changes include main ref' do
        let_it_be(:changes, freeze: false) { +"123456 789012 refs/heads/tést\n654321 210987 refs/tags/tag\n423423 797823 refs/heads/main" }

        before do
          allow(wiki.repository).to receive(:raw_changes_between).once.with('423423', '797823').and_return([])
        end

        it 'triggers a wiki update for project' do
          expect(wiki).to receive(:index_wiki_blobs)

          described_class.new(wiki, current_user, changes: post_received.changes).execute
        end

        context 'with a group wiki', :elastic do
          let_it_be(:group, freeze: false) { create(:group) }
          let_it_be(:wiki, freeze: false) { build(:group_wiki, group: group) }

          it 'triggers a wiki update' do
            expect(wiki).to receive(:index_wiki_blobs)

            described_class.new(wiki, current_user, changes: post_received.changes).execute
          end
        end
      end

      describe 'when changes do not include main ref' do
        let_it_be(:changes, freeze: false) { +"123456 789012 refs/heads/tést\n654321 210987 refs/tags/tag" }

        it 'does not trigger a wiki update' do
          expect(wiki).not_to receive(:index_wiki_blobs)

          described_class.new(wiki, current_user, changes: post_received.changes).execute
        end
      end
    end

    context 'when elasticsearch is disabled' do
      before do
        allow(wiki.container).to receive(:use_elasticsearch?).and_return(false)
        allow(wiki.repository).to receive(:raw_changes_between).once.with('423423', '797823').and_return([])
      end

      describe 'when changes include main ref' do
        let_it_be(:changes, freeze: false) { +"123456 789012 refs/heads/tést\n654321 210987 refs/tags/tag\n423423 797823 refs/heads/main" }

        it 'does nothing even if changes include main ref' do
          expect(wiki).not_to receive(:index_wiki_blobs)

          described_class.new(wiki, current_user, changes: post_received.changes).execute
        end
      end
    end
  end

  include_examples 'Git::WikiPushService', :group_wiki
end
