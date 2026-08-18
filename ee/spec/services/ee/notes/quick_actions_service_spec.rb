# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::QuickActionsService, feature_category: :team_planning do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:private_group, freeze: false) { create(:group, :private) }
  let_it_be(:project, freeze: false) { create(:project, :repository, group: group) }
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be(:assignee, freeze: false) { create(:user) }
  let_it_be(:reviewer, freeze: false) { create(:user) }
  let_it_be_with_reload(:issue) { create(:issue, project: project) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }
  let_it_be(:private_epic, freeze: false) { create(:epic, group: private_group) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project) }

  let(:service) { described_class.new(project, user) }

  def execute(note, include_message: false)
    content, update_params, message, _ = service.execute(note)
    service.apply_updates(update_params, note)

    if include_message
      [content, message]
    else
      content
    end
  end

  describe '/epic' do
    let(:note_text) { "/epic #{epic.to_reference(project)}" }
    let(:note) { create(:note_on_issue, noteable: issue, project: project, note: note_text) }

    before_all do
      group.add_guest(user)
    end

    context 'when epics are not enabled' do
      context 'on an issue' do
        it 'does not assign the epic' do
          content, message = execute(note, include_message: true)

          expect(content).to be_empty
          expect(message).to eq('Could not apply set_parent command.')
          expect(issue.epic).to be_nil
        end
      end

      context 'on a work_item' do
        let(:note) { create(:note_on_issue, noteable: work_item, project: project, note: note_text) }

        it 'does not assign the epic' do
          content, message = execute(note, include_message: true)

          expect(content).to be_empty
          expect(message).to eq('Could not apply set_parent command.')
          expect(issue.epic).to be_nil
        end
      end
    end

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when user have no access to the epic' do
        let(:note_text) { "/epic #{private_epic.to_reference(full: true)}" }

        it 'does not assign the epic' do
          content, message  = execute(note, include_message: true)

          expect(content).to be_empty
          expect(message).to eq("This parent item does not exist or you don't have sufficient permission.")
          expect(issue.epic).to be_nil
        end
      end

      context 'on an issue' do
        context 'when user has no access to the issue' do
          before do
            allow(user).to receive(:can?).and_call_original
            allow(user).to receive(:can?).with(:admin_issue_relation, issue).and_return(false)
          end

          it 'does not assign the epic' do
            content, message  = execute(note, include_message: true)

            expect(content).to be_empty
            expect(message).to eq('Could not apply set_parent command.')
            expect(issue.epic).to be_nil
          end
        end

        it 'assigns the issue to the epic' do
          expect { execute(note) }.to change { issue.reload.epic }.from(nil).to(epic)
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end

        it 'creates a system note', :sidekiq_inline do
          expect { execute(note) }.to change { Note.system.count }.from(0).to(2)
        end
      end

      context 'on a work item' do
        let(:note) { create(:note_on_work_item, noteable: work_item, project: project, note: note_text) }

        context 'when user has no access to the work_item' do
          before do
            allow(user).to receive(:can?).and_call_original
            allow(user).to receive(:can?).with(:admin_issue_relation, work_item).and_return(false)
          end

          it 'does not assign the epic' do
            content, message  = execute(note, include_message: true)

            expect(content).to be_empty
            expect(message).to eq('Could not apply set_parent command.')
            expect(work_item.reload.work_item_parent).to be_nil
          end
        end

        it 'assigns the work item to the parent' do
          expect { execute(note) }.to change { work_item.reload.work_item_parent }.from(nil).to(epic.work_item)
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end

        it 'creates a system note', :sidekiq_inline do
          expect { execute(note) }.to change { Note.system.count }.from(0).to(2)
        end
      end

      context 'on an incident' do
        before do
          issue.update!(work_item_type_id: build(:work_item_system_defined_type, :incident).id)
        end

        it 'leaves the note empty' do
          expect(execute(note)).to be_empty
        end

        it 'does not assigns the issue to the epic' do
          expect { execute(note) }.not_to change { issue.reload.epic }
        end
      end

      context 'on a merge request' do
        let(:note_mr) { create(:note_on_merge_request, project: project, noteable: merge_request, note: note_text) }

        it 'leaves the note empty' do
          expect(execute(note_mr)).to be_empty
        end
      end
    end
  end

  describe '/remove_epic' do
    let(:note_text) { "/remove_epic" }
    let(:note) { create(:note_on_issue, noteable: issue, project: project, note: note_text) }
    let_it_be_with_refind(:epic_issue) { create(:epic_issue, epic: epic, issue: issue) }

    before_all do
      group.add_guest(user)
    end

    context 'when epics are not enabled' do
      it 'does not remove the epic' do
        content, message  = execute(note, include_message: true)

        expect(content).to be_empty
        expect(message).to eq('Could not apply remove_epic command.')
        expect(issue.epic).to eq(epic)
      end
    end

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when user have no access to the issue' do
        before do
          allow(user).to receive(:can?).and_call_original
          allow(user).to receive(:can?).with(:admin_issue_relation, issue).and_return(false)
        end

        it 'does not remove the epic' do
          result = execute(note, include_message: true)

          expect(result[0]).to be_empty
          expect(result[1]).to eq('Could not apply remove_epic command.')
          expect(issue.epic).to eq(epic)
        end
      end

      context 'when user have no access to the epic' do
        let(:note_text) { "/epic #{private_epic.to_reference(full: true)}" }

        before do
          epic_issue.work_item_parent_link.update_attribute(:work_item_parent, private_epic.work_item)
          epic_issue.update_attribute(:epic, private_epic)
        end

        it 'does not remove the epic' do
          result = execute(note, include_message: true)

          expect(result[0]).to be_empty
          expect(result[1]).to eq("This parent item does not exist or you don't have sufficient permission.")
          expect(issue.epic).to eq(private_epic)
        end
      end

      context 'on an issue' do
        it 'removes the epic' do
          expect { execute(note) }.to change { issue.reload.epic }.from(epic).to(nil)
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end

        it 'creates a system note' do
          expect { execute(note) }.to change { Note.system.count }.from(0).to(2)
        end
      end

      context 'on an incident' do
        before do
          issue.assign_attributes(work_item_type_id: build(:work_item_system_defined_type, :incident).id)
          issue.save!(validate: false)
        end

        it 'leaves the note empty' do
          expect(execute(note)).to be_empty
        end
      end

      context 'on a test case' do
        before do
          issue.assign_attributes(work_item_type_id: build(:work_item_system_defined_type, :test_case).id)
          issue.save!(validate: false)
        end

        it 'leaves the note empty' do
          expect(execute(note)).to be_empty
        end
      end

      context 'on a merge request' do
        let(:note_mr) { create(:note_on_merge_request, project: project, noteable: merge_request, note: note_text) }

        it 'leaves the note empty' do
          expect(execute(note_mr)).to be_empty
        end
      end
    end
  end

  describe 'Epics' do
    describe '/close' do
      let(:note_text) { "/close" }
      let(:note) { create(:note, noteable: epic, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      context 'when epics are not enabled' do
        it 'does not close the epic' do
          expect { execute(note) }.not_to change { epic.state }
        end
      end

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'closes the epic' do
          expect { execute(note) }.to change { epic.reload.state }.from('opened').to('closed')
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end
      end
    end

    describe '/set_parent' do
      let_it_be_with_reload(:noteable) do
        create(:work_item, :epic_with_legacy_epic, namespace: group, title: "WorkItem Epic")
      end

      let_it_be_with_reload(:parent) do
        create(:work_item, :epic_with_legacy_epic, namespace: group, title: "WorkItem Parent Epic")
      end

      let_it_be(:note_text, freeze: false) { "/set_parent #{parent.to_reference}" }
      let_it_be(:note, freeze: false) { build(:note, noteable: noteable, namespace: group, note: note_text) }
      let_it_be(:epic, freeze: false) { noteable.synced_epic }
      let_it_be(:parent_epic, freeze: false) { parent.synced_epic }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when using epic iid' do
        let_it_be(:note_text, freeze: false) { "/set_parent #{parent.to_reference}" }

        it_behaves_like 'sets work item parent'
      end

      context 'when using legacy epic URL' do
        let_it_be(:url, freeze: false) { "#{Gitlab.config.gitlab.url}/#{group.full_path}/epics/#{parent.iid}" }
        let_it_be(:note_text, freeze: false) { "/set_parent #{url}" }

        it_behaves_like 'sets work item parent'
      end

      context 'with subepics disabled' do
        before do
          stub_licensed_features(subepics: false)
        end

        it 'does not assign a parent epic' do
          content, message = execute(note, include_message: true)

          expect(content).to be_empty
          expect(message).to eq('Could not apply set_parent command.')
          expect(issue.epic).to be_nil
        end
      end
    end

    describe '/add_child' do
      let_it_be(:noteable, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:child, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:second_child, freeze: false) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let_it_be(:note_text, freeze: false) { "/add_child #{child.to_reference}, #{second_child.to_reference}" }
      let_it_be(:note, freeze: false) { build(:note, noteable: noteable, project: project, note: note_text) }

      let(:children) { [child, second_child] }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      it_behaves_like 'adds child work items'

      context 'when using work item full reference' do
        let_it_be(:note_text, freeze: false) do
          "/add_child #{child.to_reference(full: true)}, #{second_child.to_reference(full: true)}"
        end

        it_behaves_like 'adds child work items'
      end

      context 'when using epic and epic work item URL' do
        let_it_be(:group_path, freeze: false) { "#{Gitlab.config.gitlab.url}/#{group.full_path}" }
        let_it_be(:url, freeze: false) do
          "#{group_path}/work_items/#{child.iid}, #{group_path}/epics/#{second_child.iid}"
        end

        let_it_be(:note_text, freeze: false) { "/add_child #{url}" }

        it_behaves_like 'adds child work items'
      end
    end

    describe '/reopen' do
      let(:note_text) { "/reopen" }
      let(:note) { create(:note, noteable: epic, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      before do
        epic.update!(state: 'closed')
        epic.issue.update!(state: 'closed')
      end

      context 'when epics are not enabled' do
        it 'does not reopen the epic' do
          expect { execute(note) }.not_to change { epic.state }
        end
      end

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'reopens the epic' do
          expect { execute(note) }.to change { epic.reload.state }.from('closed').to('opened')
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end
      end
    end

    describe '/label' do
      let(:project) { nil }
      let!(:bug) { create(:group_label, title: 'bug', group: group) }
      let!(:project_label) { create(:label, title: 'project_label', project: create(:project, group: group)) }
      let(:note_text) { "/label ~bug ~project_label" }
      let(:note) { create(:note, noteable: epic, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      context 'when epics are not enabled' do
        it 'does not add a label to the epic' do
          expect { execute(note) }.not_to change { epic.labels.count }
        end
      end

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'adds a group label to the epic' do
          expect { execute(note) }.to change { epic.reload.labels.map(&:title) }.to(['bug'])
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end
      end
    end

    describe '/unlabel' do
      let(:project) { nil }
      let!(:bug) { create(:group_label, title: 'bug', group: group) }
      let!(:feature) { create(:group_label, title: 'feature', group: group) }
      let(:note_text) { "/unlabel ~bug" }
      let(:note) { create(:note, noteable: epic, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      before do
        epic.labels = [bug, feature]
      end

      context 'when epics are not enabled' do
        it 'does not remove any label' do
          expect { execute(note) }.not_to change { epic.labels.count }
        end
      end

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        it 'removes a requested label from the epic' do
          expect { execute(note) }.to change { epic.reload.labels.map(&:title) }.to(['feature'])
        end

        it 'leaves the note empty' do
          expect(execute(note)).to eq('')
        end
      end
    end
  end

  describe '/assign_reviewer' do
    let_it_be_with_reload(:user) { create(:user) }
    let(:note_text) { %(/assign_reviewer @#{user.username} @#{reviewer.username}\n) }

    let(:multiline_assign_reviewer_text) do
      <<~HEREDOC
        /assign_reviewer #{user.to_reference}
        /assign_reviewer #{reviewer.to_reference}
      HEREDOC
    end

    before_all do
      project.add_maintainer(reviewer)
      project.add_maintainer(user)
    end

    context 'with a merge request' do
      let(:note) { create(:note_on_merge_request, note: note_text, noteable: merge_request, project: project) }

      it_behaves_like 'assigns one or more reviewers to the merge request', multiline: false do
        let(:target) { note.noteable }
      end

      it_behaves_like 'assigns one or more reviewers to the merge request', multiline: true do
        let(:note) do
          create(:note_on_merge_request, note: multiline_assign_reviewer_text, noteable: merge_request,
            project: project)
        end

        let(:target) { note.noteable }
      end
    end
  end

  describe '/request_review' do
    context 'when requesting a review from Duo bot' do
      let(:duo_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }
      let(:has_duo_access) { false }
      let(:note) { create(:note_on_merge_request, note: note_text, noteable: merge_request, project: project) }

      before_all do
        project.add_maintainer(reviewer)
        project.add_maintainer(user)
      end

      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(has_duo_access)
        merge_request.duo_code_review_attempted = nil
      end

      context 'when user lacks Duo access' do
        let(:has_duo_access) { false }
        let(:note_text) { "/request_review @#{duo_bot.username}" }

        it 'filters out Duo bot and shows access error message' do
          _, update_params, message = service.execute(note)
          expect(message).to include("You don't have access to GitLab Duo Code Review")
          expect(update_params[:reviewer_ids]).to be_nil
          expect(merge_request.duo_code_review_attempted).to eq(:manual)
        end

        context 'when also requesting a review from a regular user' do
          let(:note_text) { "/request_review @#{duo_bot.username} @#{user.username}" }

          it 'still requests a review from regular reviewers along with Duo error message' do
            _, update_params, message = service.execute(note)
            expect(message).to include("You don't have access to GitLab Duo Code Review")
            expect(message).to include("Requested a review from @#{user.username}")
            expect(update_params[:reviewer_ids]).to contain_exactly(user.id)
            expect(merge_request.duo_code_review_attempted).to eq(:manual)
          end
        end
      end

      context 'when user has Duo access' do
        let(:has_duo_access) { true }
        let(:note_text) { "/request_review @#{duo_bot.username}" }

        it 'request review from Duo bot' do
          _, update_params, message = service.execute(note)

          expect(message).to include("Requested a review from @#{duo_bot.username}")
          expect(update_params[:reviewer_ids]).to contain_exactly(duo_bot.id)
          expect(merge_request.duo_code_review_attempted).to be_nil
        end
      end
    end
  end

  describe '/assign' do
    let_it_be_with_reload(:user) { create(:user) }
    let(:note_text) { %(/assign @#{user.username} @#{assignee.username}\n) }
    let(:multiline_assign_note_text) { %(/assign @#{user.username}\n/assign @#{assignee.username}) }

    before_all do
      project.add_maintainer(assignee)
      project.add_maintainer(user)
    end

    context 'Issue assignees' do
      let(:note) { create(:note_on_issue, note: note_text, project: project) }

      it 'adds multiple assignees from the list' do
        _, update_params, message = service.execute(note)
        service.apply_updates(update_params, note)

        expected_format = /Assigned @\w+ and @\w+./

        expect(message).to match(expected_format)
        expect(message).to include("@#{assignee.username}")
        expect(message).to include("@#{user.username}")

        expect(note.noteable.assignees.count).to eq(2)
      end

      it_behaves_like 'assigning an already assigned user', false do
        let(:target) { note.noteable }
      end

      it_behaves_like 'assigning an already assigned user', true do
        let(:note) { create(:note_on_issue, note: multiline_assign_note_text, project: project) }
        let(:target) { note.noteable }
      end
    end

    context 'MergeRequest' do
      let(:note) { create(:note_on_merge_request, note: note_text, noteable: merge_request, project: project) }

      it_behaves_like 'assigning an already assigned user', false do
        let(:target) { note.noteable }
      end

      it_behaves_like 'assigning an already assigned user', true do
        let(:note) do
          create(:note_on_merge_request, note: multiline_assign_note_text, noteable: merge_request, project: project)
        end

        let(:target) { note.noteable }
      end
    end
  end

  describe '/unassign' do
    let(:note_text) { %(/unassign @#{assignee.username} @#{user.username}\n) }
    let(:multiline_unassign_note_text) { %(/unassign @#{assignee.username}\n/unassign @#{user.username}) }

    before_all do
      project.add_maintainer(user)
    end

    context 'Issue assignees' do
      let(:note) { create(:note_on_issue, note: note_text, project: project) }

      it_behaves_like 'unassigning a not assigned user', false do
        let(:target) { note.noteable }
      end

      it_behaves_like 'unassigning a not assigned user', true do
        let(:note) { create(:note_on_issue, note: multiline_unassign_note_text, project: project) }
        let(:target) { note.noteable }
      end
    end

    context 'MergeRequest' do
      let(:note) { create(:note_on_merge_request, note: note_text, noteable: merge_request, project: project) }

      it_behaves_like 'unassigning a not assigned user', false do
        let(:target) { note.noteable }
      end

      it_behaves_like 'unassigning a not assigned user', true do
        let(:note) do
          create(:note_on_merge_request, note: multiline_unassign_note_text, noteable: merge_request, project: project)
        end

        let(:target) { note.noteable }
      end
    end
  end

  describe '/unassign_reviewer' do
    let(:note_text) { %(/unassign_reviewer @#{reviewer.username} @#{user.username}\n) }

    let(:multiline_unassign_reviewer_note_text) do
      <<~HEREDOC
        /unassign_reviewer @#{reviewer.username}
        /unassign_reviewer @#{user.username}
      HEREDOC
    end

    before_all do
      project.add_maintainer(user)
      project.add_maintainer(reviewer)
    end

    context 'with a merge request' do
      let(:note) { create(:note_on_merge_request, note: note_text, noteable: merge_request, project: project) }

      it_behaves_like 'unassigning one or more reviewers', multiline: false do
        let(:target) { note.noteable }
      end

      it_behaves_like 'unassigning one or more reviewers', multiline: true do
        let(:note) do
          create(:note_on_merge_request, note: multiline_unassign_reviewer_note_text, noteable: merge_request,
            project: project)
        end

        let(:target) { note.noteable }
      end
    end
  end

  context '/promote' do
    let(:note_text) { "/promote" }
    let(:note) { create(:note_on_issue, noteable: issue, project: project, note: note_text) }

    context 'when epics are enabled' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when a user does not have permissions to promote an issue' do
        it 'does not promote an issue to an epic' do
          expect { execute(note) }.not_to change { Epic.count }
          expect(issue.reload.promoted_to_epic_id).to be_nil
        end
      end

      context 'when a user has permissions to promote an issue' do
        before_all do
          group.add_developer(user)
        end

        it 'promotes an issue to an epic' do
          expect { execute(note) }.to change { Epic.count }.by(1)
          expect(issue.reload.promoted_to_epic_id).to be_present
        end

        context 'with a double promote' do
          let(:note_text) do
            <<~HEREDOC
              /promote
              /promote
            HEREDOC
          end

          it 'only creates one epic' do
            expect { execute(note) }.to change { Epic.count }.by(1)
          end
        end

        context 'when issue was already promoted' do
          it 'does not promote issue' do
            issue.update!(promoted_to_epic_id: epic.id)

            expect { execute(note) }.not_to change { Epic.count }
          end
        end

        context 'when an issue belongs to a project without group' do
          let(:project) { create(:project) }
          let(:user) { create(:user) }
          let(:issue) { create(:issue, project: project) }
          let(:note) { create(:note_on_issue, noteable: issue, project: project, note: note_text) }

          before do
            project.add_developer(user)
          end

          it 'does not promote an issue to an epic' do
            expect { execute(note) }.not_to change { Epic.count }
          end
        end

        context 'on an incident' do
          before do
            issue.update!(work_item_type_id: build(:work_item_system_defined_type, :incident).id)
          end

          it 'does not promote to an epic' do
            expect { execute(note) }.not_to change { Epic.count }
          end
        end
      end
    end

    context 'when epics are disabled' do
      it 'does not promote an issue to an epic' do
        group.add_developer(user)

        expect { execute(note) }.not_to change { Epic.count }
      end
    end
  end

  context '/promote_to' do
    context 'with key result' do
      let_it_be_with_reload(:noteable) { create(:work_item, :key_result, project: project) }
      let_it_be(:note_text, freeze: false) { '/promote_to Objective' }
      let_it_be(:note, freeze: false) { create(:note_on_issue, noteable: noteable, project: project, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(okrs: okrs_enabled)
      end

      context 'when okrs feature is available' do
        let(:okrs_enabled) { true }

        it 'promotes key result to objective' do
          expect { execute(note) }
            .to change { noteable.work_item_type.base_type }.from('key_result').to('objective')
        end

        it 'does not promote a key result to an objective when okrs_mvc FF is disabled' do
          stub_feature_flags(okrs_mvc: false)
          expect { execute(note) }.not_to change { noteable.work_item_type.base_type }
        end

        context 'when the type name is lower case' do
          let_it_be(:note_text, freeze: false) { '/promote_to objective' }

          it 'promotes key result to objective' do
            expect { execute(note) }
              .to change { noteable.work_item_type.base_type }.from('key_result').to('objective')
          end
        end
      end

      context 'when okrs feature is not available' do
        let(:okrs_enabled) { false }

        it 'does not promote a key result to an objective' do
          expect { execute(note) }.not_to change { noteable.work_item_type.base_type }
        end
      end
    end
  end

  context 'with issue types' do
    shared_examples 'note on issue type that does not support time tracking' do
      let(:note) { build(:note_on_issue, project: project, noteable: noteable) }

      before do
        note.note = note_text
      end

      context '/spend' do
        let(:note_text) { "/spend 1h 2021-05-26" }

        it 'does not change time spent' do
          expect { execute(note) }.not_to change { noteable.reload.time_spent }
        end
      end

      context '/estimate' do
        let(:note_text) { "/estimate 1h" }

        it 'does not execute time estimate' do
          expect { execute(note) }.not_to change { noteable.reload.time_estimate }
        end
      end
    end

    context 'when issue does not support quick actions' do
      before_all do
        group.add_developer(user)
      end

      context 'for requirement' do
        it_behaves_like 'note on issue type that does not support time tracking' do
          let(:noteable) { create(:requirement, project: project) }
        end
      end

      context 'for test case' do
        it_behaves_like 'note on issue type that does not support time tracking' do
          let(:noteable) { create(:quality_test_case, project: project) }
        end
      end
    end

    context 'for /promote_to epic' do
      let_it_be_with_reload(:noteable) { create(:work_item, :issue, project: project) }
      let_it_be(:note_text, freeze: false) { '/promote_to Epic' }
      let(:note) { create(:note_on_issue, noteable: noteable, project: project, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when it is valid' do
        it 'promotes the issue to an epic' do
          expect { service.execute(note) }.to change { Epic.count }.by(1)

          expect(noteable.reload.promoted_to_epic).to be_present
          expect(noteable.work_item_transition.reload.promoted_to_epic).to be_present
        end

        context 'when project_work_item_epics feature flag is disabled' do
          before do
            stub_feature_flags(project_work_item_epics: false)
          end

          it 'promotes the issue to an epic via group namespace fallback' do
            expect { service.execute(note) }.to change { Epic.count }.by(1)

            expect(noteable.reload.promoted_to_epic).to be_present
          end
        end
      end

      context 'when it is not valid' do
        let_it_be(:parent_link, freeze: false) do
          create(:parent_link, :with_epic_issue,
            work_item_parent: create(:work_item, :epic_with_legacy_epic, namespace: project.group), work_item: noteable)
        end

        before do
          epic_type = build(:work_item_system_defined_type, :epic)

          allow(WorkItems::TypesFramework::SystemDefined::HierarchyRestriction).to receive(:find_by).with(
            parent_type_id: epic_type.id,
            child_type_id: epic_type.id
          ).and_return(
            instance_double(
              WorkItems::TypesFramework::SystemDefined::HierarchyRestriction,
              maximum_depth: 0,
              parent_type_id: epic_type.id,
              child_type_id: epic_type.id
            )
          )
        end

        it 'does not promote the issue and returns an error message' do
          _content, _update_params, message, _ = service.execute(note)

          expect(noteable.reload.promoted_to_epic).to be_nil
          expect(noteable.work_item_transition.reload.promoted_to_epic).to be_nil
          expect(message).to eq "Failed to promote this work item: Work item reached maximum depth."
        end
      end
    end

    context 'for /type epic' do
      let_it_be_with_reload(:noteable) { create(:work_item, :issue, project: project) }
      let(:note_text) { '/type Epic' }
      let(:note) { create(:note_on_issue, noteable: noteable, project: project, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_licensed_features(epics: true, subepics: true)
      end

      context 'when epics feature is not licensed' do
        before do
          stub_licensed_features(epics: false, subepics: false)
        end

        it 'does not promote the issue and returns an error message' do
          _content, _update_params, message, _ = service.execute(note)

          expect(noteable.reload.promoted_to_epic).to be_nil
          expect(message).to eq "Failed to convert this work item: Provided type is not supported."
        end
      end

      context 'when it is valid' do
        it 'promotes the issue to an epic' do
          expect { service.execute(note) }.to change { Epic.count }.by(1)

          expect(noteable.reload.promoted_to_epic).to be_present
          expect(noteable.work_item_transition.reload.promoted_to_epic).to be_present
        end

        context 'when project_work_item_epics feature flag is disabled' do
          before do
            stub_feature_flags(project_work_item_epics: false)
          end

          it 'promotes the issue to an epic via group namespace fallback' do
            allow(::WorkItems::TypesFramework::Provider).to receive(:new).and_call_original
            expect(::WorkItems::TypesFramework::Provider).to receive(:new).with(project.group).and_call_original

            expect { service.execute(note) }.to change { Epic.count }.by(1)

            expect(noteable.reload.promoted_to_epic).to be_present
          end
        end
      end

      context 'when it is not valid' do
        let_it_be(:parent_link, freeze: false) do
          create(:parent_link, :with_epic_issue,
            work_item_parent: create(:work_item, :epic_with_legacy_epic, namespace: project.group), work_item: noteable)
        end

        before do
          epic_type = build(:work_item_system_defined_type, :epic)

          allow(WorkItems::TypesFramework::SystemDefined::HierarchyRestriction).to receive(:find_by).with(
            parent_type_id: epic_type.id,
            child_type_id: epic_type.id
          ).and_return(
            instance_double(
              WorkItems::TypesFramework::SystemDefined::HierarchyRestriction,
              maximum_depth: 0,
              parent_type_id: epic_type.id,
              child_type_id: epic_type.id
            )
          )
        end

        it 'does not promote the issue and returns an error message' do
          _content, _update_params, message, _ = service.execute(note)

          expect(noteable.reload.promoted_to_epic).to be_nil
          expect(noteable.work_item_transition.reload.promoted_to_epic).to be_nil
          expect(message).to eq "Failed to promote this work item: Work item reached maximum depth."
        end
      end

      context 'when the project has no parent group' do
        let_it_be(:project) { create(:project) }
        let(:noteable) { create(:work_item, :issue, project: project) }
        let(:note) { create(:note_on_issue, noteable: noteable, project: project, note: note_text) }

        before do
          project.add_developer(user)
        end

        it 'does not promote the issue and returns an error message' do
          _content, _update_params, message, _ = service.execute(note)

          expect(noteable.reload.promoted_to_epic).to be_nil
          expect(message).to eq "Failed to convert this work item: Provided type is not supported."
        end
      end
    end
  end

  context '/checkin_reminder' do
    context 'with and objective' do
      let_it_be_with_reload(:noteable) { create(:work_item, :objective, project: project) }
      let_it_be(:progress, freeze: false) { create(:progress, work_item: noteable) }
      let_it_be(:note_text, freeze: false) { '/checkin_reminder weekly' }
      let(:note) { create(:note_on_issue, noteable: noteable, project: project, note: note_text) }

      before_all do
        group.add_developer(user)
      end

      before do
        stub_feature_flags(okr_checkin_reminders: checkin_reminders_enabled)
      end

      context 'when checkin reminder feature is enabled' do
        let(:checkin_reminders_enabled) { true }

        it 'sets the checkin reminder to weekly' do
          expect { execute(note) }
            .to change { noteable.progress.reminder_frequency }.from('never').to('weekly')
        end

        context 'when the frequency is capitalized' do
          let_it_be(:note_text, freeze: false) { '/checkin_reminder WEEKLY' }

          it 'sets the checkin reminder to weekly' do
            expect { execute(note) }
              .to change { noteable.progress.reminder_frequency }.from('never').to('weekly')
          end
        end

        context 'when the frequency is not a valid option' do
          let_it_be(:note_text, freeze: false) { '/checkin_reminder foo' }

          it 'does not set the checkin reminder' do
            expect { execute(note) }.not_to change { noteable.progress.reminder_frequency }
          end
        end

        context 'when the frequency contains a hypen' do
          let_it_be(:note_text, freeze: false) { '/checkin_reminder twice-monthly' }

          it 'does not set the checkin reminder' do
            expect { execute(note) }
              .to change { noteable.progress.reminder_frequency }.from('never').to('twice_monthly')
          end
        end

        context 'when the frequency contains an underscore' do
          let_it_be(:note_text, freeze: false) { '/checkin_reminder twice_monthly' }

          it 'does not set the checkin reminder' do
            expect { execute(note) }
              .to change { noteable.progress.reminder_frequency }.from('never').to('twice_monthly')
          end
        end
      end

      context 'when checkin reminder feature is not enabled' do
        let(:checkin_reminders_enabled) { false }

        it 'does not set the checkin reminder' do
          expect { execute(note) }.not_to change { noteable.progress.reminder_frequency }
        end
      end
    end
  end

  context '/q' do
    let_it_be(:user, freeze: false) { create(:user) }
    let(:amazon_q_enabled) { false }
    let(:note) { create(:note_on_issue, project: project, noteable: issue, note: note_text) }
    let(:trigger_service) { instance_double(::Ai::AmazonQ::AmazonQTriggerService) }

    before_all do
      project.add_developer(user)
    end

    before do
      allow(::Ai::AmazonQ).to receive(:enabled?).and_return(amazon_q_enabled)
    end

    context 'when Amazon Q is not enabled' do
      let(:note_text) { '/q dev' }

      it 'does not run command' do
        expect(::Ai::AmazonQ::AmazonQTriggerService).not_to receive(:new)

        result = execute(note, include_message: true)

        expect(result[0]).to be_empty
        expect(result[1]).to eq('Could not apply q command.')
      end
    end

    context 'when Amazon Q is enabled' do
      let(:amazon_q_enabled) { true }
      let(:note_text) { "/q #{command}" }
      let(:discussion_id) { note.discussion_id }
      let(:note_with_quick_action) { note }

      shared_examples 'successful Q command' do
        it 'runs the command' do
          expect(trigger_service).to receive(:execute)
          expect(::Ai::AmazonQ::AmazonQTriggerService).to receive(:new).with(
            user: user,
            command: command,
            input: '',
            note: note_with_quick_action,
            source: source,
            discussion_id: discussion_id
          ).and_return(trigger_service)

          result = execute(note_with_quick_action, include_message: true)

          expect(result[0]).to be_empty
          expect(result[1]).to eq('Q got your message!')
        end
      end

      context 'with issue' do
        let(:source) { issue }

        where(command: ::Ai::AmazonQ::Commands::ISSUE_SUBCOMMANDS)

        with_them do
          it_behaves_like 'successful Q command'
        end
      end

      context 'with merge_request' do
        let(:note) { create(:note_on_merge_request, project: project, noteable: merge_request, note: note_text) }
        let(:source) { merge_request }

        where(command: ::Ai::AmazonQ::Commands::MERGE_REQUEST_SUBCOMMANDS)

        with_them do
          it_behaves_like 'successful Q command'
        end

        context 'with a note on an existing discussion' do
          let(:note_with_quick_action) do
            build(:note, noteable: merge_request, project: project, discussion_id: note.discussion_id, note: "/q dev")
          end

          let(:command) { 'dev' }

          it_behaves_like 'successful Q command'
        end
      end

      context 'when using unsupported sub-command for issue' do
        let_it_be(:note_text, freeze: false) { '/q unknown' }

        it 'returns an error' do
          expect(::Ai::AmazonQ::AmazonQTriggerService).not_to receive(:new)

          content, update_params, message, _ = service.execute(note)

          expect(content).to be_blank
          expect(update_params).to be_empty
          expect(message).to eq('Unsupported issue command: unknown')
        end
      end

      context 'when using unsupported sub-command for epic' do
        let_it_be(:note_text, freeze: false) { '/q unknown' }
        let_it_be(:note, freeze: false) { create(:note_on_epic, project: project, note: note_text) }

        it 'returns an error' do
          expect(::Ai::AmazonQ::AmazonQTriggerService).not_to receive(:new)

          content, update_params, message, _ = service.execute(note)

          expect(content).to be_blank
          expect(update_params).to be_empty
          expect(message).to eq('Could not apply q command.')
        end
      end

      context 'when using unsupported sub-command transform for merge request' do
        let_it_be(:note_text, freeze: false) { '/q transform' }
        let_it_be(:note, freeze: false) do
          create(:note_on_merge_request, project: project, noteable: merge_request, note: note_text)
        end

        it 'returns an error' do
          expect(::Ai::AmazonQ::AmazonQTriggerService).not_to receive(:new)

          content, update_params, message, _ = service.execute(note)

          expect(content).to be_blank
          expect(update_params).to be_empty
          expect(message).to eq('Unsupported merge request command: transform')
        end
      end

      context 'when using deprecated test command for merge request' do
        let_it_be(:note_text, freeze: false) { '/q test' }
        let_it_be(:note, freeze: false) do
          create(:note_on_merge_request, project: project, noteable: merge_request, note: note_text)
        end

        it 'returns a deprecation error' do
          expect(::Ai::AmazonQ::AmazonQTriggerService).not_to receive(:new)

          content, update_params, message, _ = service.execute(note)

          expect(content).to be_blank
          expect(update_params).to be_empty
          expect(message).to eq(
            '/q test is now supported by using /q dev in an issue or merge request. ' \
              'To generate unit tests for this MR, add an inline comment and enter /q ' \
              'dev along with a comment about the tests you want written.'
          )
        end
      end
    end
  end
end
