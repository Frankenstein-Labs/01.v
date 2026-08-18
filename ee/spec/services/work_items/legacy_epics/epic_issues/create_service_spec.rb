# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::LegacyEpics::EpicIssues::CreateService, feature_category: :portfolio_management do
  describe '#execute' do
    let(:references) { [valid_reference] }
    let_it_be(:non_member) { create(:user) }
    let_it_be(:guest) { create(:user) }
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:other_group) { create(:group, :public, guests: guest) }
    let_it_be(:project) { create(:project, :public, group: other_group) }
    let_it_be(:issue) { create(:issue, project: project) }
    let_it_be(:issue2) { create(:issue, project: project) }
    let_it_be(:issue3) { create(:issue, project: project) }
    let_it_be(:valid_reference) { issue.to_reference(full: true) }
    let_it_be_with_reload(:epic) { create(:epic, group: group) }
    let(:expected_issue_system_note_action) { 'relate_to_parent' }
    let(:expected_epic_system_note_action) { 'relate_to_child' }
    let(:expected_issue_system_note) { "added #{epic.work_item.to_reference(issue.project)} as parent item" }
    let(:epic_system_note) { Note.where(noteable_id: epic.work_item.id, noteable_type: 'Issue').last }
    let(:expected_noteable_type) { 'Issue' }
    let(:expected_epic_system_note) { "added #{issue.to_reference(epic.group)} as child item" }

    def assign_issue(references)
      params = { issuable_references: references }

      described_class.new(epic, user, params).execute
    end

    subject(:execute) { assign_issue(references) }

    shared_examples 'returns success' do
      let(:created_link) { EpicIssue.find_by!(issue_id: issue.id) }

      it 'creates a new relationship and updates epic' do
        expect { subject }.to change { EpicIssue.count }.by(1).and change { WorkItems::ParentLink.count }.by(1)

        expect(created_link).to have_attributes(epic: epic)
      end

      it 'orders the epic issue to the first place and moves the existing ones down' do
        existing_link = create(:epic_issue, :with_parent_link, epic: epic, issue: issue3)

        subject

        expect(created_link.relative_position).to be < existing_link.reload.relative_position
      end

      it 'returns success status and created links', :aggregate_failures do
        subject

        expect(subject.keys).to match_array([:status, :created_references])
        expect(subject[:status]).to eq(:success)
        expect(subject[:created_references].count).to eq(1)
        expect(subject[:created_references]).to match_array([created_link])
      end

      describe 'async actions', :sidekiq_inline, :aggregate_failures do
        it 'creates 1 system note for epic and 1 system note for issue' do
          expect { subject }.to change { Note.count }.by(2)
        end

        it 'creates a note for epic correctly' do
          subject

          expect(epic_system_note.note).to eq(expected_epic_system_note)
          expect(epic_system_note.author).to eq(user)
          expect(epic_system_note.project).to be_nil
          expect(epic_system_note.noteable_type).to eq(expected_noteable_type)
          expect(epic_system_note.system_note_metadata.action).to eq(expected_epic_system_note_action)
        end

        it 'creates a note for issue correctly' do
          subject
          note = Note.find_by(noteable_id: issue.id, noteable_type: 'Issue')

          expect(note.note).to eq(expected_issue_system_note)
          expect(note.author).to eq(user)
          expect(note.project).to eq(issue.project)
          expect(note.noteable_type).to eq('Issue')
          expect(note.system_note_metadata.action).to eq(expected_issue_system_note_action)
        end
      end
    end

    shared_examples 'returns an error' do
      it 'returns an error and does not create a relationship' do
        expect { subject }.not_to change { EpicIssue.count }

        expect(subject).to eq(message: 'No matching issue found. Make sure that you are adding a valid issue URL.',
          status: :error, http_status: 404)
      end
    end

    context 'when epics feature is disabled' do
      let_it_be(:user) { guest }

      subject(:execute) { assign_issue([valid_reference]) }

      include_examples 'returns an error'
    end

    context 'when epics feature is enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when user is only member of a project in the group' do
        let_it_be_with_reload(:group) { create(:group, :private) }
        let_it_be_with_reload(:project) { create(:project, :private, group: group) }
        let_it_be_with_reload(:user) { create(:user, guest_of: project) }
        let_it_be_with_reload(:valid_reference) { create(:issue, project: project).to_reference(full: true) }

        it 'sets the parent correctly' do
          expect { execute }.to change { EpicIssue.count }.by(1)
            .and(change { WorkItems::ParentLink.count }.by(1))

          expect(execute[:status]).to eq(:success)
        end
      end

      context 'when user has permissions to link the issue' do
        let_it_be(:user) { guest }

        context 'when the reference list is empty' do
          let(:references) { [] }

          include_examples 'returns an error'

          it 'does not create a system note' do
            expect { execute }.not_to change { Note.count }
          end
        end

        context 'when there is an issue to relate' do
          context 'when shortcut for Issue is given' do
            let(:references) { [issue.to_reference] }

            include_examples 'returns an error'
          end

          context 'when target_issuable param is used' do
            subject do
              described_class.new(epic, user, { target_issuable: [issue] }).execute
            end

            include_examples 'returns success'
          end

          context 'when a full reference is given' do
            include_examples 'returns success'

            it 'does not perform N + 1 queries', :use_clean_rails_memory_store_caching, :request_store do
              pending 'https://gitlab.com/gitlab-org/gitlab/-/issues/438295'

              allow(SystemNoteService).to receive(:epic_issue)

              params = { issuable_references: [valid_reference] }
              control_count = ActiveRecord::QueryRecorder.new { described_class.new(epic, user, params).execute }.count

              user = create(:user)
              group = create(:group)
              project = create(:project, group: group)
              issues = create_list(:issue, 5, project: project)
              epic = create(:epic, group: group)
              group.add_guest(user)

              params = { issuable_references: issues.map { |i| i.to_reference(full: true) } }

              # threshold 28 because ~5 queries are generated for each insert
              # (work item parent link checks for sync, savepoint, find, exists, relative_position get, insert,
              # release savepoint)
              # and we insert 5 issues instead of 1 which we do for control count
              expect { described_class.new(epic, user, params).execute }
                .not_to exceed_query_limit(control_count)
                .with_threshold(28)
            end
          end

          context 'when an issue link is given' do
            subject do
              assign_issue([
                Gitlab::Routing.url_helpers.namespace_project_issue_url(namespace_id: issue.project.namespace,
                  project_id: issue.project, id: issue.iid)
              ])
            end

            include_examples 'returns success'
          end

          context 'when a link of an issue in a subgroup is given' do
            let_it_be(:subgroup) { create(:group, parent: group) }
            let_it_be(:project2) { create(:project, group: subgroup) }
            let_it_be(:issue) { create(:issue, project: project2) }

            let(:references) do
              [Gitlab::Routing.url_helpers.namespace_project_issue_url(namespace_id: issue.project.namespace,
                project_id: issue.project, id: issue.iid)]
            end

            before_all do
              project2.add_guest(user)
            end

            include_examples 'returns success'
          end

          context 'when multiple valid issues are given' do
            let(:references) { [issue, issue2].map { |i| i.to_reference(full: true) } }
            let(:created_link1) { EpicIssue.find_by!(issue_id: issue.id) }
            let(:created_link2) { EpicIssue.find_by!(issue_id: issue2.id) }

            it 'creates new relationships' do
              expect { execute }.to change { EpicIssue.count }.by(2)

              expect(created_link1).to have_attributes(epic: epic)
              expect(created_link2).to have_attributes(epic: epic)
            end

            it 'places each issue at the start',
              quarantine: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/18786' do
              execute

              expect(created_link2.relative_position).to be < created_link1.relative_position
            end

            it 'orders the epic issues to the first place and moves the existing ones down' do
              existing_link = create(:epic_issue, :with_parent_link, epic: epic, issue: issue3)

              execute

              expect([created_link1, created_link2].map(&:relative_position))
                .to all(be < existing_link.reset.relative_position)
            end

            it 'returns success status and created links', :aggregate_failures do
              expect(execute.keys).to match_array([:status, :created_references])
              expect(execute[:status]).to eq(:success)
              expect(execute[:created_references].count).to eq(2)
            end

            it 'creates 2 system notes for each issue', :sidekiq_inline do
              expect { execute }.to change { Note.count }.from(0).to(4)
            end
          end
        end

        context 'when there are invalid references' do
          let_it_be_with_reload(:epic) { create(:epic, confidential: true, group: group) }
          let_it_be(:valid_issue) { create(:issue, :confidential, project: project) }
          let_it_be(:invalid_issue1) { create(:issue, project: project) }
          let_it_be(:invalid_issue2) { create(:issue, project: project) }

          let(:references) do
            [invalid_issue1.to_reference(full: true), valid_issue.to_reference(full: true),
              invalid_issue2.to_reference(full: true)]
          end

          before_all do
            project.add_reporter(user)
            group.add_reporter(user)
          end

          it 'creates no links' do
            # The ParentLinks::CreateService creates the records but responds with an error for the invalid ones.
            # This raises an error in the HierarchyWidget and rolls back the transaction.
            expect { execute }.to not_change { EpicIssue.count }.and not_change { WorkItems::ParentLink.count }
          end

          it 'returns error status' do
            expect(execute[:status]).to eq(:error)
            expect(execute[:http_status]).to eq(422)
            expect(execute[:message]).to include("#{invalid_issue1.to_reference} cannot be added: cannot assign a " \
              "non-confidential issue to a confidential parent")
              .and include("#{invalid_issue2.to_reference} cannot be added: cannot assign a non-confidential issue " \
                "to a confidential parent")
              .and include("Make the issue confidential and try again")
          end
        end

        context "when assigning issuable which don't support epics" do
          let(:references) { [incident.to_reference(full: true)] }
          let_it_be(:incident) { create(:incident, project: project) }

          context 'when user is a reporter' do
            let_it_be(:reporter_user) { create(:user) }
            let(:user) { reporter_user }

            before_all do
              project.add_reporter(reporter_user)
              group.add_reporter(reporter_user)
            end

            it 'returns validation error' do
              error_message = "#{incident.to_reference} cannot be added: " \
                "it's not allowed to add this type of parent item"

              expect(execute[:status]).to eq(:error)
              expect(execute[:http_status]).to eq(422)
              expect(execute[:message]).to eq(error_message)
            end
          end

          context 'when user is a guest' do
            let(:user) { guest }

            it 'returns not found error' do
              expect(execute[:status]).to eq(:error)
              expect(execute[:http_status]).to eq(404)
              expect(execute[:message]).to eq('No matching issue found. ' \
                'Make sure that you are adding a valid issue URL.')
            end
          end
        end
      end

      context 'when user does not have permissions to link the issue' do
        let_it_be(:user) { non_member }

        include_examples 'returns an error'
      end

      context 'when assigning issue(s) to the same epic' do
        let_it_be(:user) { guest }

        before do
          assign_issue([valid_reference])
          epic.reload
        end

        it 'no relationship is created' do
          expect { execute }.not_to change { EpicIssue.count }
        end

        it 'does not create notes' do
          expect { execute }.not_to change { Note.count }
        end

        it 'returns an error' do
          expect(execute).to eq(message: 'Issue(s) already assigned', status: :error, http_status: 409)
        end

        context 'when at least one of the issues is still not assigned to the epic' do
          let_it_be(:valid_reference) { issue2.to_reference(full: true) }

          subject { assign_issue([valid_reference, issue.to_reference(full: true)]) }

          include_examples 'returns success'
        end
      end

      context 'when an issue is already assigned to another epic', :sidekiq_inline do
        let_it_be(:user) { guest }
        let_it_be_with_reload(:another_epic) { create(:epic, group: group) }
        let_it_be_with_reload(:existing_epic_issue) { create(:epic_issue, :with_parent_link, epic: epic, issue: issue) }

        before do
          issue.reload
        end

        subject(:execute) do
          params = { issuable_references: [valid_reference] }

          described_class.new(another_epic, user, params).execute
        end

        it 'does not create a new association' do
          expect { execute }.not_to change { EpicIssue.count }
        end

        it 'updates the existing association' do
          expect { execute }.to change { existing_epic_issue.reload.epic }.from(epic).to(another_epic)
        end

        it 'returns success status and created links', :aggregate_failures do
          expect(execute.keys).to match_array([:status, :created_references])
          expect(execute[:status]).to eq(:success)
          expect(execute[:created_references].count).to eq(1)
        end

        it 'creates system notes' do
          expect { execute }.to change { Note.count }.by(3)
        end

        it 'creates a note correctly for the old epic' do
          execute

          note = Note.find_by(system: true, noteable_type: expected_noteable_type, noteable_id: epic.work_item.id)

          expect(note.note).to eq(
            "moved child issue #{issue.to_reference(epic.group)} " \
              "to #{another_epic.work_item.to_reference(issue.project)}"
          )
          expect(note.system_note_metadata.action).to eq('moved')
        end

        it 'creates a note correctly for the new epic' do
          execute

          note = Note.find_by(system: true, noteable_type: expected_noteable_type,
            noteable_id: another_epic.work_item.id)

          expect(note.note).to eq("added #{issue.to_reference(epic.group)} as child item")
          expect(note.system_note_metadata.action).to eq('relate_to_child')
        end

        it 'creates a note correctly for the issue' do
          execute

          note = Note.find_by(system: true, noteable_type: expected_noteable_type, noteable_id: issue.id)

          expect(note.note).to eq("added #{another_epic.work_item.to_reference(issue.project)} as parent item")
          expect(note.system_note_metadata.action).to eq('relate_to_parent')
        end
      end

      context 'when issue from non group project is given' do
        let_it_be(:another_issue) { create :issue }
        let_it_be(:user) { guest }
        let(:references) { [another_issue.to_reference(full: true)] }

        before do
          another_issue.project.add_guest(user)
        end

        it 'returns success status and created links', :aggregate_failures do
          expect(execute.keys).to match_array([:status, :created_references])
          expect(execute[:status]).to eq(:success)
          expect(execute[:created_references].count).to eq(1)
        end
      end
    end
  end
end
