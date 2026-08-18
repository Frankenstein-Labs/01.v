# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TodoService, feature_category: :notifications do
  let_it_be(:author) { create(:user, username: 'author') }
  let_it_be(:non_member) { create(:user, username: 'non_member') }
  let_it_be(:member) { create(:user, username: 'member') }
  let_it_be(:guest) { create(:user, username: 'guest') }
  let_it_be(:admin) { create(:admin, username: 'administrator') }
  let_it_be(:john_doe) { create(:user, username: 'john_doe') }
  let_it_be(:skipped) { create(:user, username: 'skipped') }
  let(:project) { nil }

  let(:skip_users) { [skipped] }
  let(:service) { described_class.new }

  describe 'Epics' do
    let(:users) { [author, non_member, member, guest, admin, john_doe, skipped] }
    let(:mentions) { users.map(&:to_reference).join(' ') }
    let(:combined_mentions) { member.to_reference + ", what do you think? cc: " + [guest, admin, skipped].map(&:to_reference).join(' ') }

    let(:description_mentions) { "- [ ] Task 1\n- [ ] Task 2 FYI: #{mentions}" }
    let(:description_directly_addressed) { "#{mentions}\n- [ ] Task 1\n- [ ] Task 2" }

    let_it_be_with_reload(:group) { create(:group) }

    let(:epic) { create(:epic, group: group, author: author, description: description_mentions) }

    let(:todos_for) { [] }
    let(:todos_not_for) { [] }
    let(:target) { epic }

    before_all do
      group.add_guest(guest)
      group.add_developer(author)
      group.add_developer(member)
    end

    before do
      stub_licensed_features(epics: true)
    end

    shared_examples_for 'todos creation' do
      it 'creates todos for users mentioned' do
        if todos_for.count > 0
          params = todo_params
            .merge(user: todos_for)
            .reverse_merge(target: target, project: nil, group: group, author: author, state: :pending)

          expect { execute }
            .to change { Todo.where(params).count }.from(0).to(todos_for.count)
        end
      end

      it 'does not create todos for users not mentioned or without permissions' do
        execute

        params = todo_params
          .reverse_merge(target: target, project: nil, group: group, author: author, state: :pending)

        todos_not_for.each_with_index do |user, index|
          expect(Todo.where(params.merge(user: user)).count)
            .to eq(0), "expected not to create a todo for user '#{user.username}''"
        end
      end
    end

    context 'Epics' do
      describe '#update_epic' do
        let(:execute) { service.update_epic(epic, author, skip_users) }

        context 'for mentioned users' do
          let(:todo_params) { { action: Todo::MENTIONED } }
          let(:todos_for) { [author, non_member, member, guest, admin, john_doe] }
          let(:todos_not_for) { [skipped] }

          include_examples 'todos creation'
        end

        context 'for directly addressed users' do
          before do
            epic.update!(description: description_directly_addressed)
          end

          let(:todo_params) { { action: Todo::DIRECTLY_ADDRESSED } }
          let(:todos_for) { [author, non_member, member, guest, admin, john_doe] }
          let(:todos_not_for) { [skipped] }

          include_examples 'todos creation'
        end

        context 'when toggling task list items' do
          before do
            epic.update!(description: "- [x] Task 1\n- [x] Task 2 FYI: #{mentions}")
          end

          it 'does not create todos' do
            expect { execute }.not_to change { Todo.count }
          end
        end
      end

      describe '#new_note' do
        let(:note) { create(:note, noteable: epic, project: nil, author: john_doe, note: mentions) }

        context 'when a note is created for an epic' do
          let!(:first_todo) do
            create(:todo, :assigned,
              user: john_doe, project: nil, group: group, target: epic, author: author)
          end

          let!(:second_todo) do
            create(:todo, :assigned,
              user: john_doe, project: nil, group: group, target: epic, author: author)
          end

          it 'marks pending epic todos for the note author as done' do
            service.new_note(note, john_doe)

            expect(first_todo.reload).to be_done
            expect(second_todo.reload).to be_done
          end

          it 'does not mark pending epic todos for the note author as done for system notes' do
            system_note = create(:system_note, noteable: epic)

            service.new_note(system_note, john_doe)

            expect(first_todo.reload).to be_pending
            expect(second_todo.reload).to be_pending
          end
        end

        context 'mentions' do
          let(:execute) { service.new_note(note, author) }

          context 'for mentioned users' do
            before do
              note.update!(note: description_mentions)
            end

            let(:todo_params) { { action: Todo::MENTIONED } }
            let(:todos_for) { users }
            let(:todos_not_for) { [] }

            include_examples 'todos creation'
          end

          context 'for directly addressed users' do
            before do
              note.update!(note: description_directly_addressed)
            end

            let(:todo_params) { { action: Todo::DIRECTLY_ADDRESSED } }
            let(:todos_for) { users }
            let(:todos_not_for) { [] }

            include_examples 'todos creation'
          end

          context 'combined' do
            before do
              note.update!(note: combined_mentions)
            end

            context 'mentioned users' do
              let(:todo_params) { { action: Todo::MENTIONED } }
              let(:todos_for) { [guest, admin, skipped] }

              include_examples 'todos creation'
            end

            context 'directly addressed users' do
              let(:todo_params) { { action: Todo::DIRECTLY_ADDRESSED } }
              let(:todos_for) { [member] }

              include_examples 'todos creation'
            end
          end
        end
      end
    end
  end

  context 'Merge Requests' do
    let(:project) { create(:project) }
    let(:merge_request) { create(:merge_request, source_project: project, author: author, description: description) }

    let(:assignee) { create(:user) }
    let(:approver_1) { create(:user) }
    let(:approver_2) { create(:user) }
    let(:approver_3) { create(:user) }
    let(:code_owner) { create(:user, username: 'codeowner') }
    let(:description) { 'FYI: ' + [john_doe, approver_1].map(&:to_reference).join(' ') }

    before do
      project.add_guest(guest)
      project.add_developer(author)
      project.add_developer(member)
      project.add_developer(john_doe)
      project.add_developer(skipped)
      project.add_developer(approver_1)
      project.add_developer(approver_2)
      project.add_developer(approver_3)
      project.add_developer(code_owner)

      allow(merge_request).to receive(:code_owners).and_return([code_owner])

      service.new_merge_request(merge_request, author)
    end

    shared_examples 'when user is mentioned' do
      it 'creates a todo' do
        # for each valid mentioned user

        should_create_todo(user: john_doe, target: merge_request, action: Todo::MENTIONED)
      end
    end

    shared_examples 'when code owner is mentioned' do
      let(:description) { 'FYI: ' + [code_owner].map(&:to_reference).join(' ') }

      it 'creates a todo' do
        should_create_todo(user: code_owner, target: merge_request, action: Todo::MENTIONED)
      end
    end

    describe '#new_merge_request' do
      context 'when the merge request has approvers' do
        it_behaves_like 'when user is mentioned'
        it_behaves_like 'when code owner is mentioned'
      end
    end
  end

  context 'Merge Requests' do
    let(:project) { create(:project, :private, :repository) }
    let(:other_project) { create(:project, :private, :repository) }
    let(:merge_request) { create(:merge_request, source_project: project, author: author) }
    let(:other_mr) { create(:merge_request, source_project: other_project, author: author) }

    describe '#merge_train_removed' do
      let(:merge_participants) { [admin, create(:user)] }

      before do
        allow(merge_request).to receive(:merge_participants).and_return(merge_participants)
      end

      it 'creates a pending todo for each merge_participant' do
        merge_request.update!(merge_when_pipeline_succeeds: true, merge_user: admin)
        service.merge_train_removed(merge_request)

        merge_participants.each do |participant|
          should_create_todo(user: participant, author: participant, target: merge_request, action: Todo::MERGE_TRAIN_REMOVED)
        end
      end

      it 'resolves merge_train_removed todos when a MR got merged' do
        first_todo = create(:todo, :pending, :merge_train_removed, user: john_doe, project: project, target: merge_request, author: author)
        second_todo = create(:todo, :pending, :merge_train_removed, user: author, project: project, target: merge_request, author: john_doe)
        other_mr_todo = create(:todo, :pending, :merge_train_removed, user: author, project: project, target: other_mr, author: john_doe)

        service.merge_merge_request(merge_request, admin)

        expect(first_todo.reload).to be_done
        expect(second_todo.reload).to be_done
        expect(other_mr_todo.reload).to be_pending
      end
    end

    describe '#request_okr_checkin' do
      let_it_be(:project_member) { create(:project_member, :maintainer) }
      let_it_be(:project) { project_member.project }
      let_it_be(:user) { project_member.user }
      let_it_be(:kr) { create(:work_item, :key_result, project: project) }

      it 'creates a pending todo for the key_result assignee' do
        kr.assignees = [user]

        service.request_okr_checkin(kr, user)

        should_create_todo(user: user, author: kr.author, target: kr, action: Todo::OKR_CHECKIN_REQUESTED)
      end
    end
  end

  describe 'Wiki pages' do
    let_it_be(:group) { create(:group, :private, developers: [author, john_doe]) }
    let_it_be_with_reload(:wiki_page_meta) { create(:wiki_page_meta, :for_wiki_page, container: group) }

    let(:note) do
      create(
        :note,
        namespace: group,
        project: nil,
        noteable: wiki_page_meta,
        author: author,
        note: "Hey #{john_doe.to_reference}"
      )
    end

    before do
      stub_licensed_features(group_wikis: true)
    end

    it 'creates a todo with the relevant group id for mentioned user on new diff note' do
      attributes = {
        user: john_doe,
        target: wiki_page_meta,
        action: Todo::MENTIONED,
        note: note,
        group: group,
        author: author,
        state: :pending
      }

      expect { service.new_note(note, author) }.to change { Todo.where(attributes).count }.by(1)
    end
  end

  describe '#added_approver' do
    let_it_be(:users, freeze: false) { create_list(:user, 2) }
    let_it_be(:merge_request) { create(:merge_request) }
    let_it_be(:project) { merge_request.project }

    it 'creates pending todo for the approver' do
      service.added_approver(users, merge_request)

      should_create_todo(user: users[0], author: merge_request.author, target: merge_request, action: ::Todo::ADDED_APPROVER)
      should_create_todo(user: users[1], author: merge_request.author, target: merge_request, action: ::Todo::ADDED_APPROVER)
    end
  end

  describe "duo" do
    let_it_be(:duo_bot) { ::Users::Internal.in_organization(author.organization_id).duo_code_review_bot }

    describe '#duo_core_access_granted' do
      let_it_be(:user_with_pending_todo) { create(:todo, :pending, :duo_core_access).user }
      let_it_be(:user_with_done_todo) { create(:todo, :done, :duo_core_access).user }
      let_it_be(:users_without_notifications) { create_list(:user, 2) }

      context 'when multiple users have received the todo and multiple users have not received the todo' do
        it 'creates a pending todo for only the users who have not received one', :aggregate_failures do
          expect_next_instance_of(::Users::UpdateTodoCountCacheService, users_without_notifications.map(&:id)) do |inst|
            expect(inst).to receive(:execute).and_call_original
          end

          service.duo_core_access_granted(users_without_notifications + [user_with_pending_todo, user_with_done_todo])

          should_create_todo(
            user: users_without_notifications[0],
            author: duo_bot,
            target: users_without_notifications[0],
            action: Todo::DUO_CORE_ACCESS_GRANTED
          )
          should_create_todo(
            user: users_without_notifications[1],
            author: duo_bot,
            target: users_without_notifications[1],
            action: Todo::DUO_CORE_ACCESS_GRANTED
          )
          expect(users_without_notifications[0].todos.count).to eq(1)
          expect(users_without_notifications[1].todos.count).to eq(1)
          expect(user_with_pending_todo.todos.count).to eq(1)
          expect(user_with_done_todo.todos.count).to eq(1)
        end
      end

      context 'when there are no users who have received the todo' do
        it 'creates a pending todo for multiple users', :aggregate_failures do
          expect_next_instance_of(::Users::UpdateTodoCountCacheService, users_without_notifications.map(&:id)) do |inst|
            expect(inst).to receive(:execute).and_call_original
          end

          service.duo_core_access_granted(users_without_notifications)

          should_create_todo(
            user: users_without_notifications[0],
            author: duo_bot,
            target: users_without_notifications[0],
            action: Todo::DUO_CORE_ACCESS_GRANTED
          )
          should_create_todo(
            user: users_without_notifications[1],
            author: duo_bot,
            target: users_without_notifications[1],
            action: Todo::DUO_CORE_ACCESS_GRANTED
          )
          expect(users_without_notifications[0].todos.count).to eq(1)
          expect(users_without_notifications[1].todos.count).to eq(1)
        end
      end

      context 'when all of the users have already received the todo' do
        it 'does not create any todos', :aggregate_failures do
          expect_next_instance_of(::Users::UpdateTodoCountCacheService, []) do |service_instance|
            expect(service_instance).to receive(:execute).and_call_original
          end

          service.duo_core_access_granted([user_with_pending_todo, user_with_done_todo])

          expect(user_with_pending_todo.todos.count).to eq(1)
          expect(user_with_done_todo.todos.count).to eq(1)
        end
      end
    end

    describe '#duo_pro_access_granted' do
      it 'creates a pending todo for the user' do
        service.duo_pro_access_granted(author)

        should_create_todo(user: author, author: duo_bot, target: author, action: Todo::DUO_PRO_ACCESS_GRANTED)
      end
    end

    describe '#duo_enterprise_access_granted' do
      it 'creates a pending todo for the user' do
        service.duo_enterprise_access_granted(author)

        should_create_todo(user: author, author: duo_bot, target: author, action: Todo::DUO_ENTERPRISE_ACCESS_GRANTED)
      end
    end
  end

  describe '#duo_workflow_input_required' do
    let_it_be(:group) { create(:group) }
    let_it_be(:workflow_project) { create(:project, group: group) }
    let(:workflow) { create(:duo_workflows_workflow, project: workflow_project) }

    it 'creates a pending todo for the workflow user' do
      service.duo_workflow_input_required(workflow)

      should_create_todo(
        user: workflow.user,
        author: workflow.user,
        target: workflow,
        action: Todo::DUO_WORKFLOW_INPUT_REQUIRED,
        project: workflow_project
      )
    end

    it 'does not create duplicate todos' do
      service.duo_workflow_input_required(workflow)
      service.duo_workflow_input_required(workflow)

      expect(Todo.where(target: workflow, action: Todo::DUO_WORKFLOW_INPUT_REQUIRED).count).to eq(1)
    end

    context 'when workflow is namespace level' do
      let(:workflow) { create(:duo_workflows_workflow, namespace: group) }

      it 'does not create todos for non project workflows' do
        expect { service.duo_workflow_input_required(workflow) }.not_to change { Todo.where(target: workflow, action: Todo::DUO_WORKFLOW_INPUT_REQUIRED).count }
      end
    end
  end

  describe '#resolve_duo_workflow_input_required_todo' do
    let_it_be(:workflow_project) { create(:project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, project: workflow_project) }
    let_it_be(:todo) do
      create(:todo, :duo_workflow_input_required,
        user: workflow.user,
        author: workflow.user,
        target: workflow,
        project: workflow_project)
    end

    it 'marks the todo as done' do
      service.resolve_duo_workflow_input_required_todo(workflow)

      expect(todo.reload).to be_done
    end

    it 'does not resolve todos of other action types for the same target' do
      other_todo = create(:todo,
        action: Todo::MENTIONED,
        user: workflow.user,
        author: workflow.user,
        target: workflow,
        project: workflow_project)

      service.resolve_duo_workflow_input_required_todo(workflow)

      expect(other_todo.reload).to be_pending
    end
  end

  def should_create_todo(attributes = {})
    attributes.reverse_merge!(
      project: project,
      author: author,
      state: :pending
    )

    expect(Todo.where(attributes).count).to eq 1
  end

  def should_not_create_todo(attributes = {})
    attributes.reverse_merge!(
      project: project,
      author: author,
      state: :pending
    )

    expect(Todo.where(attributes).count).to eq 0
  end
end
