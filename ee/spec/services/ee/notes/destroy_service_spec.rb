# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::DestroyService, feature_category: :team_planning do
  let_it_be_with_refind(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let_it_be_with_refind(:note) do
    create(:note_on_issue, project: project, author: user)
  end

  subject(:service) { described_class.new(project, user) }

  describe '#execute' do
    describe 'refresh analytics comment data' do
      let(:analytics_mock) { instance_double('Analytics::RefreshCommentsData') }

      it 'invokes forced Analytics::RefreshCommentsData' do
        allow(Analytics::RefreshCommentsData).to receive(:for_note).with(note).and_return(analytics_mock)

        expect(analytics_mock).to receive(:execute).with(force: true)

        service.execute(note)
      end
    end

    describe 'publish to status page' do
      let(:execute) { service.execute(note) }
      let(:issue_id) { note.noteable_id }

      include_examples 'trigger status page publish'
    end

    describe 'tracking via usage ping' do
      let_it_be(:note) do
        create(:note_on_epic, author: user)
      end

      it 'tracks epic note destroy' do
        expect(::Gitlab::UsageDataCounters::EpicActivityUniqueCounter).to receive(:track_epic_note_destroyed_action)
          .with(author: user, namespace: note.noteable.group)

        service.execute(note)
      end
    end

    context 'for group wiki page note' do
      let_it_be(:group) { create(:group) }
      let(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }
      let(:note) do
        create(:note, project: nil, namespace: group, noteable: wiki_page_meta, author: user, note: "Old note")
      end

      before do
        stub_licensed_features(group_wikis: true)
      end

      it_behaves_like 'internal event tracking' do
        let(:event) { 'delete_wiki_page_note' }
        let(:category) { described_class.name }
        let(:namespace) { group }
        let(:project) { nil }

        subject(:track_event) { described_class.new(nil, user).execute(note) }
      end
    end

    describe 'audit events' do
      it 'audits with comment_deleted event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'comment_deleted',
            target: note,
            additional_details: {
              body: note.note
            },
            stream_only: true
          )
        ).and_call_original

        service.execute(note)
      end

      context 'when note is on a personal snippet' do
        let!(:note) { create(:note_on_personal_snippet) }

        it 'does not audit the event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          service.execute(note)
        end
      end
    end
  end
end
