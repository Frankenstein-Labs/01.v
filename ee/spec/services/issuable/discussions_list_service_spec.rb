# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuable::DiscussionsListService, feature_category: :team_planning do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :private, group: group) }
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }
  let_it_be(:label_2) { create(:group_label, group: group) }

  let(:finder_params_for_issuable) { {} }

  subject(:discussions_service) { described_class.new(current_user, issuable, finder_params_for_issuable) }

  describe 'fetching notes for incidents' do
    let_it_be_with_reload(:issuable) { create(:incident, project: project) }

    it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 7
  end

  describe 'fetching notes for epics' do
    let_it_be_with_reload(:issuable) { create(:epic, group: group) }

    before do
      stub_licensed_features(epics: true)
    end

    it 'returns same discussions for epic and epic work item' do
      epic_discussions = described_class.new(current_user, issuable, finder_params_for_issuable).execute
      work_item_discussions = described_class.new(
        current_user, issuable.sync_object, finder_params_for_issuable
      ).execute

      expect(epic_discussions.count).to eq(work_item_discussions.count)
    end

    it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 5

    describe 'fetching notes for epic work item' do
      let_it_be_with_reload(:epic) { create(:epic, group: group) }
      let_it_be(:issuable) { epic.work_item }

      before do
        stub_licensed_features(epics: true)
      end

      it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 5
    end

    context 'when fetching system notes with references' do
      let_it_be(:public_group) { create(:group, :public) }
      let_it_be(:public_project) { create(:project, :public, group: public_group) }
      let_it_be_with_reload(:issue) { create(:issue, project: public_project) }

      before do
        stub_licensed_features(epics: true)
      end

      context 'with epic in private group' do
        let_it_be_with_reload(:epic) { create(:epic, group: group) }
        let_it_be(:epic_system_note, freeze: false) do
          create(:system_note,
            noteable: epic, namespace: epic.group, note: "added issue #{issue.to_reference(full: true)}"
          )
        end

        let_it_be(:epic_system_note_metadata) do
          create(:system_note_metadata, note: epic_system_note, action: 'relate_to_child')
        end

        it 'does not return system note link on epic' do
          notes = described_class.new(nil, epic, finder_params_for_issuable).execute

          expect(notes).to be_empty
        end

        it 'does not return system note link on epic work item' do
          notes = described_class.new(nil, epic.work_item, finder_params_for_issuable).execute

          expect(notes).to be_empty
        end
      end

      context 'with epic in public group' do
        let_it_be_with_reload(:epic) { create(:epic, group: public_group) }
        let_it_be(:epic_system_note, freeze: false) do
          create(:system_note,
            noteable: epic, namespace: epic.group, note: "added issue #{issue.to_reference(full: true)}"
          )
        end

        let_it_be(:epic_system_note_metadata) do
          create(:system_note_metadata, note: epic_system_note, action: 'relate_to_child')
        end

        it 'returns system note link on epic' do
          notes = described_class.new(nil, epic, finder_params_for_issuable).execute

          expect(notes).not_to be_empty
        end

        it 'returns system note link on epic work item' do
          notes = described_class.new(nil, epic.work_item, finder_params_for_issuable).execute

          expect(notes).not_to be_empty
        end

        context 'with issue in private project' do
          let_it_be_with_reload(:issue) { create(:issue, project: project) }
          let_it_be_with_reload(:epic) { create(:epic, group: public_group) }
          let_it_be(:epic_system_note, freeze: false) do
            create(:system_note,
              noteable: epic, namespace: epic.group, note: "added issue #{issue.to_reference(full: true)}"
            )
          end

          let_it_be(:epic_system_note_metadata) do
            create(:system_note_metadata, note: epic_system_note, action: 'relate_to_child')
          end

          it 'returns system note link on epic' do
            notes = described_class.new(nil, epic, finder_params_for_issuable).execute

            expect(notes).to be_empty
          end

          it 'returns system note link on epic work item' do
            notes = described_class.new(nil, epic.work_item, finder_params_for_issuable).execute

            expect(notes).to be_empty
          end
        end
      end
    end
  end

  describe 'fetching notes for issue' do
    before do
      stub_licensed_features(epics: true)
    end

    context 'when issue exists at the group level' do
      let_it_be_with_reload(:issuable) { create(:issue, :group_level, namespace: group) }

      context 'with epics license enabled' do
        it_behaves_like 'listing issuable discussions', user_role: :guest, internal_discussions: 1, total_discussions: 7
      end

      context 'with epics license disabled' do
        before_all do
          group.add_developer(current_user)
        end

        before do
          stub_licensed_features(epics: false)
        end

        it 'does not return any notes' do
          expect(discussions_service.execute).to be_empty
        end
      end
    end

    context 'when fetching system notes with references' do
      let_it_be(:public_group) { create(:group, :public) }
      let_it_be(:public_project) { create(:project, :public, group: public_group) }
      let_it_be_with_reload(:issue) { create(:issue, project: public_project) }

      context 'with epic in private group' do
        let_it_be_with_reload(:epic) { create(:epic, group: group) }
        let_it_be(:epic_system_note, freeze: false) do
          create(:system_note,
            noteable: issue, project: issue.project, note: "added parent epic #{epic.to_reference(full: true)}"
          )
        end

        let_it_be(:epic_system_note_metadata) do
          create(:system_note_metadata, note: epic_system_note, action: 'relate_to_parent')
        end

        it 'does not return system note link on issue' do
          notes = described_class.new(nil, issue, finder_params_for_issuable).execute

          expect(notes).to be_empty
        end
      end

      context 'with epic in public group' do
        let_it_be_with_reload(:epic) { create(:epic, group: public_group) }
        let_it_be(:epic_system_note, freeze: false) do
          create(:system_note,
            noteable: issue, project: issue.project, note: "added parent epic #{epic.to_reference(full: true)}"
          )
        end

        let_it_be(:epic_system_note_metadata) do
          create(:system_note_metadata, note: epic_system_note, action: 'relate_to_parent')
        end

        it 'returns system note link on epic' do
          notes = described_class.new(nil, issue, finder_params_for_issuable).execute

          expect(notes).not_to be_empty
        end
      end
    end
  end

  describe 'fetching notes for vulnerabilities' do
    let_it_be_with_reload(:issuable) { create(:vulnerability, project: project) }

    before_all do
      group.add_developer(current_user)

      create(:note, system: true, project: issuable.project, noteable: issuable)
      create(:note, system: true, project: issuable.project, noteable: issuable)
      create(:note, system: true, project: issuable.project, noteable: issuable)

      disc_start = create(:discussion_note_on_issue, noteable: issuable, project: issuable.project, note: "a comment")
      create(:note,
        discussion_id: disc_start.discussion_id, noteable: issuable,
        project: issuable.project, note: "reply to a comment")
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    it "returns all notes" do
      discussions = discussions_service.execute
      expect(discussions.count).to eq(4)
    end

    context 'with paginated results' do
      let(:finder_params_for_issuable) { { per_page: 2 } }
      let(:next_page_cursor) { { cursor: discussions_service.paginator.cursor_for_next_page } }

      it "returns next page notes" do
        next_page_discussions_service = described_class.new(current_user, issuable,
          finder_params_for_issuable.merge(next_page_cursor))
        discussions = next_page_discussions_service.execute

        expect(discussions.count).to eq(2)
        expect(discussions.last.notes.map(&:note)).to match_array(["a comment", "reply to a comment"])
      end
    end

    context 'and system notes only' do
      let(:finder_params_for_issuable) { { notes_filter: UserPreference::NOTES_FILTERS[:only_activity] } }

      it "returns system notes" do
        discussions = discussions_service.execute

        expect(discussions.count { |disc| disc.notes.any?(&:system) }).to be > 0
        expect(discussions.count { |disc| !disc.notes.any?(&:system) }).to eq(0)
      end
    end

    context 'and user comments only' do
      let(:finder_params_for_issuable) { { notes_filter: UserPreference::NOTES_FILTERS[:only_comments] } }

      it "returns user comments" do
        discussions = discussions_service.execute

        expect(discussions.count { |disc| disc.notes.any?(&:system) }).to eq(0)
        expect(discussions.count { |disc| !disc.notes.any?(&:system) }).to be > 0
      end
    end
  end
end
