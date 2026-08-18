# frozen_string_literal: true

require 'spec_helper'

RSpec.describe QuickActions::InterpretService, feature_category: :team_planning do
  let(:current_user) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let(:developer2) { create(:user) }
  let(:user) { create(:user) }
  let_it_be_with_refind(:user2) { create(:user) }
  let_it_be_with_refind(:user3) { create(:user) }
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, :public, group: group, developers: developer) }
  let_it_be_with_reload(:issue) { create(:issue, project: project) }

  let(:service) { described_class.new(container: project, current_user: current_user) }

  before do
    stub_licensed_features(multiple_issue_assignees: true,
      multiple_merge_request_reviewers: true,
      multiple_merge_request_assignees: true)

    project.add_developer(current_user)
  end

  shared_examples 'quick action is unavailable' do |action|
    it 'does not recognize action' do
      expect(service.available_commands(target).map { |command| command[:name] }).not_to include(action)
    end
  end

  shared_examples 'quick action is available' do |action|
    it 'does recognize action' do
      expect(service.available_commands(target).map { |command| command[:name] }).to include(action)
    end
  end

  shared_examples 'failed command' do |error_msg|
    let(:match_msg) { error_msg ? eq(error_msg) : be_empty }

    it 'populates {} if content contains an unsupported command' do
      _, updates, _ = service.execute(content, issuable)

      expect(updates).to be_empty
    end

    it "returns #{error_msg || 'an empty'} message" do
      _, _, message = service.execute(content, issuable)

      expect(message).to match_msg
    end
  end

  shared_examples 'copy_metadata command' do
    it 'fetches issue or merge request and copies labels and milestone if content contains /copy_metadata reference' do
      source_issuable # populate the issue
      todo_label # populate this label
      inreview_label # populate this label
      _, updates, _ = service.execute(content, issuable)

      expect(updates[:add_label_ids]).to match_array([inreview_label.id, todo_label.id])

      if source_issuable.milestone
        expect(updates[:milestone_id]).to eq(source_issuable.milestone.id)
      else
        expect(updates).not_to have_key(:milestone_id)
      end
    end

    it 'returns the copy metadata message' do
      _, _, message = service.execute("/copy_metadata #{source_issuable.to_reference}", issuable)
      translated_string = _("Copied labels and milestone from %{source_issuable_to_reference}.")
      formatted_message = format(translated_string, source_issuable_to_reference: source_issuable.to_reference.to_s)

      expect(message).to eq(formatted_message)
    end
  end

  describe '#execute' do
    let(:merge_request) { create(:merge_request, source_project: project) }

    context 'assign command' do
      context 'there is a group' do
        let(:group) { create(:group) }

        before do
          group.add_developer(user)
          group.add_developer(user2)
          group.add_developer(user3)
        end

        it 'assigns to group members' do
          cmd = "/assign #{group.to_reference}"

          _, updates, _ = service.execute(cmd, issue)

          expect(updates).to include(assignee_ids: match_array([user.id, user2.id, user3.id]))
        end

        it 'does not assign to more than QuickActions::UsersFinder::MAX_QUICK_ACTION_USERS' do
          stub_const('Gitlab::QuickActions::UsersExtractor::MAX_QUICK_ACTION_USERS', 2)

          cmd = "/assign #{group.to_reference}"

          _, updates, messages = service.execute(cmd, issue)

          expect(updates).to be_blank
          expect(messages).to include('Too many users')
        end
      end

      context 'Issue' do
        it 'fetches assignees and populates them if content contains /assign' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/unassign @#{user2.username}\n/assign @#{user3.username}", issue)

          expect(updates[:assignee_ids]).to match_array([user.id, user3.id])
        end

        context 'with test_case issue type' do
          it 'does not mark to update assignee' do
            test_case = create(:quality_test_case, project: project)

            _, updates = service.execute("/assign @#{user3.username}", test_case)

            expect(updates[:assignee_ids]).to be_nil
          end
        end

        context 'assign command with multiple assignees' do
          it 'fetches assignee and populates assignee_ids if content contains /assign' do
            issue.update!(assignee_ids: [user.id])

            _, updates = service.execute("/unassign @#{user.username}\n/assign @#{user2.username} @#{user3.username}", issue)

            expect(updates[:assignee_ids]).to match_array([user2.id, user3.id])
          end
        end
      end

      context 'Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        it 'fetches assignees and populates them if content contains /assign' do
          merge_request.update!(assignee_ids: [user.id])

          _, updates = service.execute("/assign @#{user2.username}", merge_request)

          expect(updates[:assignee_ids]).to match_array([user.id, user2.id])
        end

        context 'assign command with a group of users' do
          let(:group) { create(:group) }
          let(:project) { create(:project, group: group) }
          let(:group_members) { create_list(:user, 3) }
          let(:command) { "/assign #{group.to_reference}" }

          before do
            group_members.each { group.add_developer(_1) }
          end

          it 'adds group members' do
            merge_request.update!(assignee_ids: [user.id])

            _, updates = service.execute(command, merge_request)

            expect(updates[:assignee_ids]).to match_array [user.id, *group_members.map(&:id)]
          end
        end

        context 'assign command with multiple assignees' do
          it 'fetches assignee and populates assignee_ids if content contains /assign' do
            merge_request.update!(assignee_ids: [user.id])

            _, updates = service.execute("/assign @#{user.username}\n/assign @#{user2.username} @#{user3.username}", issue)

            expect(updates[:assignee_ids]).to match_array([user.id, user2.id, user3.id])
          end

          context 'unlicensed' do
            before do
              stub_licensed_features(multiple_merge_request_assignees: false)
            end

            it 'does not recognize /assign with multiple user references' do
              merge_request.update!(assignee_ids: [user.id])

              _, updates = service.execute("/assign @#{user2.username} @#{user3.username}", merge_request)

              expect(updates[:assignee_ids]).to match_array([user2.id])
            end
          end
        end
      end
    end

    context 'assign_reviewer command (alias for request_review)' do
      context 'with a merge request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        it 'fetches reviewers and populates them if content contains /assign_reviewer' do
          merge_request.update!(reviewer_ids: [user.id])

          _, updates = service.execute("/assign_reviewer @#{user2.username}\n/assign_reviewer @#{user3.username}", merge_request)

          expect(updates[:reviewer_ids]).to match_array([user.id, user2.id, user3.id])
        end

        context 'assign command with multiple reviewers' do
          it 'assigns multiple reviewers while respecting previous assignments' do
            merge_request.update!(reviewer_ids: [user.id])

            _, updates = service.execute("/assign_reviewer @#{user.username}\n/assign_reviewer @#{user2.username} @#{user3.username}", merge_request)

            expect(updates[:reviewer_ids]).to match_array([user.id, user2.id, user3.id])
          end
        end
      end
    end

    context 'unassign_reviewer command' do
      let(:content) { '/unassign_reviewer' }
      let(:merge_request) { create(:merge_request, source_project: project) }
      let(:merge_request_not_persisted) { build(:merge_request, source_project: project) }

      context 'unassign_reviewer command with multiple assignees' do
        it 'unassigns both reviewers if content contains /unassign_reviewer @user @user1' do
          merge_request.update!(reviewer_ids: [user.id, user2.id, user3.id])

          _, updates = service.execute("/unassign_reviewer @#{user.username} @#{user2.username}", merge_request)

          expect(updates[:reviewer_ids]).to match_array([user3.id])
        end

        it 'does not unassign reviewers if the content cannot be parsed' do
          merge_request.update!(reviewer_ids: [user.id, user2.id, user3.id])

          _, updates, msg = service.execute("/unassign_reviewer nobody", merge_request)

          expect(updates[:reviewer_ids]).to be_nil
          expect(msg).to eq "Could not apply unassign_reviewer command. Failed to find users for 'nobody'."
        end

        context 'with "me" alias' do
          context 'when the current user is referenced both by username and "me"' do
            let(:content) do
              <<-QUICKACTION
/assign me
/assign_reviewer #{developer2.to_reference} #{current_user.to_reference}
/unassign_reviewer me
              QUICKACTION
            end

            it 'correctly removes the reviewer' do
              _, updates, _ = service.execute(content, merge_request)

              expect(updates[:reviewer_ids]).to match_array([developer2.id])
            end

            it 'correctly removes the reviewer even for non-persisted merge requests' do
              _, updates, _ = service.execute(content, merge_request_not_persisted)

              expect(updates[:reviewer_ids]).to match_array([developer2.id])
            end
          end
        end
      end
    end

    context 'unassign command' do
      let(:content) { '/unassign' }

      context 'Issue' do
        it 'unassigns user if content contains /unassign @user' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/assign @#{user3.username}\n/unassign @#{user2.username}", issue)

          expect(updates[:assignee_ids]).to match_array([user.id, user3.id])
        end

        it 'unassigns both users if content contains /unassign @user @user1' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/assign @#{user3.username}\n/unassign @#{user2.username} @#{user3.username}", issue)

          expect(updates[:assignee_ids]).to match_array([user.id])
        end

        it 'unassigns all the users if content contains /unassign' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/assign @#{user3.username}\n/unassign", issue)

          expect(updates[:assignee_ids]).to be_empty
        end

        it 'does not apply command if the argument cannot be parsed' do
          issue.update!(assignee_ids: [user.id, user2.id])

          _, updates, msg = service.execute("/assign nobody", issue)

          expect(updates[:assignee_ids]).to be_nil
          expect(msg).to eq "Could not apply assign command. Failed to find users for 'nobody'."
        end
      end

      context 'with a Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        it 'unassigns user if content contains /unassign @user' do
          merge_request.update!(assignee_ids: [user.id, user2.id])

          _, updates = service.execute("/unassign @#{user2.username}", merge_request)

          expect(updates[:assignee_ids]).to match_array([user.id])
        end

        describe 'applying unassign command with multiple assignees' do
          it 'unassigns both users if content contains /unassign @user @user1' do
            merge_request.update!(assignee_ids: [user.id, user2.id, user3.id])

            _, updates = service.execute("/unassign @#{user.username} @#{user2.username}", merge_request)

            expect(updates[:assignee_ids]).to match_array([user3.id])
          end

          context 'when unlicensed' do
            before do
              stub_licensed_features(multiple_merge_request_assignees: false)
            end

            it 'does not recognize /unassign @user' do
              merge_request.update!(assignee_ids: [user.id, user2.id, user3.id])

              _, updates = service.execute("/unassign @#{user.username}", merge_request)

              expect(updates[:assignee_ids]).to be_empty
            end
          end
        end
      end
    end

    context 'reassign command' do
      let(:content) { "/reassign @#{current_user.username}" }

      context 'Merge Request' do
        let(:merge_request) { create(:merge_request, source_project: project) }

        context 'unlicensed' do
          before do
            stub_licensed_features(multiple_merge_request_assignees: false)
          end

          it 'does not recognize /reassign @user' do
            _, updates = service.execute(content, merge_request)

            expect(updates).to be_empty
          end
        end

        it 'reassigns user if content contains /reassign @user' do
          _, updates = service.execute("/reassign @#{current_user.username}", merge_request)

          expect(updates[:assignee_ids]).to match_array([current_user.id])
        end

        context 'it reassigns multiple users' do
          let(:additional_user) { create(:user) }

          it 'reassigns user if content contains /reassign @user' do
            _, updates = service.execute("/reassign @#{current_user.username} @#{additional_user.username}", merge_request)

            expect(updates[:assignee_ids]).to match_array([current_user.id, additional_user.id])
          end
        end
      end

      context 'Issue' do
        let(:content) { "/reassign @#{current_user.username}" }

        before do
          issue.update!(assignee_ids: [user.id])
        end

        context 'unlicensed' do
          before do
            stub_licensed_features(multiple_issue_assignees: false)
          end

          it 'does not recognize /reassign @user' do
            _, updates = service.execute(content, issue)

            expect(updates).to be_empty
          end
        end

        it 'reassigns user if content contains /reassign @user' do
          _, updates = service.execute("/reassign @#{current_user.username}", issue)

          expect(updates[:assignee_ids]).to match_array([current_user.id])
        end

        context 'with test_case issue type' do
          it 'does not mark to update assignee' do
            test_case = create(:quality_test_case, project: project)

            _, updates = service.execute("/reassign @#{current_user.username}", test_case)

            expect(updates[:assignee_ids]).to be_nil
          end
        end

        context 'it reassigns multiple users' do
          let(:additional_user) { create(:user) }

          it 'reassigns user if content contains /reassign @user' do
            _, updates = service.execute("/reassign @#{current_user.username} @#{additional_user.username}", issue)

            expect(updates[:assignee_ids]).to match_array([current_user.id, additional_user.id])
          end
        end
      end
    end

    context 'reassign_reviewer command' do
      let(:content) { "/reassign_reviewer @#{current_user.username}" }

      context 'unlicensed' do
        before do
          stub_licensed_features(multiple_merge_request_reviewers: false)
        end

        it 'does not recognize /reassign_reviewer @user' do
          content = "/reassign_reviewer @#{current_user.username}"
          _, updates = service.execute(content, merge_request)

          expect(updates).to be_empty
        end
      end

      it 'reassigns reviewer if content contains /reassign_reviewer @user' do
        _, updates = service.execute("/reassign_reviewer @#{current_user.username}", merge_request)

        expect(updates[:reviewer_ids]).to match_array([current_user.id])
      end
    end

    context 'iteration command' do
      let_it_be(:root_group) { create(:group, :private) }
      let_it_be(:group) { create(:group, :private, parent: root_group) }
      let_it_be(:project) { create(:project, :private, :repository, group: group) }
      let_it_be_with_reload(:work_item_issue) { create(:work_item, project: project) }

      context 'when iterations are enabled' do
        before do
          stub_licensed_features(iterations: true)
        end

        context 'when iteration exists' do
          let_it_be_with_reload(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

          let(:content) { "/iteration #{iteration.to_reference(project)}" }

          context 'with permissions' do
            before do
              group.add_developer(current_user)
            end

            it 'does not assign iteration when reference does not match any iteration' do
              _, updates, message = service.execute("/iteration *iteration:#{non_existing_record_id}", issue)

              expect(updates).to be_empty
              expect(message).to eq(_("Could not apply iteration command. Failed to find the referenced iteration."))
            end

            shared_examples 'assigns iteration' do |factory|
              let(:issuable) do
                factory == :issue ? issue : build(factory, project: project)
              end

              it 'assigns an iteration' do
                _, updates, message = service.execute(content, issuable)

                expect(updates).to eq(iteration: iteration)
                expect(message).to eq("Set the iteration to #{iteration.to_reference}.")
              end
            end

            it_behaves_like 'assigns iteration', :issue

            context 'when issuable is a work item' do
              it_behaves_like 'assigns iteration', :work_item
            end

            context 'when issuable is an incident' do
              it_behaves_like 'assigns iteration', :incident
            end

            context 'when iteration is started' do
              before do
                iteration.start!
              end

              it_behaves_like 'assigns iteration', :issue
            end
          end

          context 'when the user does not have enough permissions' do
            before do
              allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
              allow(current_user).to receive(:can?).with(:admin_issue, project).and_return(false)
              allow(current_user).to receive(:can?).with(:admin_work_item, project).and_return(false)
            end

            it 'returns an error message' do
              [issue, work_item_issue].each do |issuable|
                _, updates, message = service.execute(content, issuable)

                expect(updates).to be_empty
                expect(message).to eq('Could not apply iteration command.')
              end
            end
          end
        end

        context 'with --current and --next options' do
          before do
            group.add_developer(current_user)
          end

          context "with iterations cadence reference" do
            let_it_be(:cadence) { create(:iterations_cadence, title: "one cadence", group: root_group) }
            let_it_be(:past_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 10.days.ago) }
            let_it_be(:current_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago) }
            let_it_be(:next_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 10.days.from_now) }

            let_it_be(:another_cadence) { create(:iterations_cadence, title: "another cadence", group: root_group) }
            let_it_be(:another_current_iteration) { create(:iteration, :with_due_date, iterations_cadence: another_cadence, start_date: 2.days.ago) }

            let_it_be(:empty_cadence) { create(:iterations_cadence, title: "empty cadence", group: root_group) }

            let_it_be(:inaccessible_cadence) { create(:iterations_cadence, title: "another cadence") }

            it 'does not assign any iteration when the referenced cadence is empty' do
              _, updates, message = service.execute("/iteration #{empty_cadence.to_reference} --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. No current iteration found for the cadence.'))

              _, updates, message = service.execute("/iteration #{empty_cadence.to_reference} --next", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. No upcoming iteration found for the cadence.'))
            end

            it 'does not assign any iteration when referencing non-existent iterations cadence' do
              _, updates, message = service.execute("/iteration [cadence:\"foobar cadence\"] --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. Failed to find the referenced iteration cadence.'))

              _, updates, message = service.execute("/iteration [cadence:#{non_existing_record_id}] --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. Failed to find the referenced iteration cadence.'))
            end

            it 'does not assign any iteration when referencing unauthorized iterations cadence' do
              _, updates, message = service.execute("/iteration #{inaccessible_cadence.to_reference} --current", issue)
              expect(updates).to be_empty
              expect(message).to eq(_('Could not apply iteration command. Failed to find the referenced iteration cadence.'))
            end

            it 'does not assign any iteration when option are missing' do
              _, updates, message = service.execute("/iteration #{cadence.to_reference}", issue)
              expect(updates).to be_empty
              expect(message).to eq(_("Could not apply iteration command. Missing option --current or --next."))
            end

            context 'with --current option' do
              where(:content) do
                [
                  [lazy { "/iteration #{cadence.to_reference} --current" }],
                  [lazy { "/iteration [cadence:\"#{cadence.title}\"] --current" }]
                ]
              end

              with_them do
                it 'assigns the current iteration of the referenced iterations cadence' do
                  _, updates, message = service.execute(content, issue)

                  expect(updates).to eq(iteration: current_iteration)
                  expect(message).to eq("Set the iteration to #{current_iteration.to_reference}.")
                end
              end
            end

            context 'with --next option' do
              where(:content) do
                [
                  [lazy { "/iteration #{cadence.to_reference} --next" }],
                  [lazy { "/iteration [cadence:\"#{cadence.title}\"] --next" }]
                ]
              end

              with_them do
                it 'assigns the next upcoming iteration of the referenced iterations cadence' do
                  _, updates, message = service.execute(content, issue)

                  expect(updates).to eq(iteration: next_iteration)
                  expect(message).to eq("Set the iteration to #{next_iteration.to_reference}.")
                end
              end
            end
          end

          context "without iterations cadence reference" do
            let_it_be(:cadence) { create(:iterations_cadence, title: "cadence", group: group) }
            let_it_be(:current_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 2.days.ago) }
            let_it_be(:next_iteration) { create(:iteration, :with_due_date, iterations_cadence: cadence, start_date: 10.days.from_now) }

            context 'when a group hierarchy has a single iterations cadence' do
              it 'assigns the current iteration from the iterations cadence' do
                _, updates, message = service.execute("/iteration --current", issue)

                expect(updates).to eq(iteration: current_iteration)
                expect(message).to eq("Set the iteration to #{current_iteration.to_reference}.")
              end

              it 'assigns the next iteration from the iterations cadence' do
                _, updates, message = service.execute("/iteration --next", issue)

                expect(updates).to eq(iteration: next_iteration)
                expect(message).to eq("Set the iteration to #{next_iteration.to_reference}.")
              end
            end

            context 'when a group hierarchy has multiple iterations cadences' do
              before_all do
                create(:iterations_cadence, title: "another cadence", group: group)
              end

              it 'does not assign any iteration' do
                _, updates, message = service.execute("/iteration --current", issue)
                expect(updates).to be_empty
                expect(message).to eq(_('Could not apply iteration command. There are multiple cadences but no cadence is specified.'))

                _, updates, message = service.execute("/iteration --next", issue)
                expect(updates).to be_empty
                expect(message).to eq(_('Could not apply iteration command. There are multiple cadences but no cadence is specified.'))
              end
            end
          end
        end
      end

      context 'when iterations are disabled' do
        let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

        let(:content) { "/iteration #{iteration.to_reference(project)}" }

        before do
          stub_licensed_features(iterations: false)
        end

        it 'does not recognize /iteration' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end
    end

    context 'remove_iteration command' do
      let_it_be(:iteration) { create(:iteration, iterations_cadence: create(:iterations_cadence, group: group)) }

      let(:content) { '/remove_iteration' }

      context 'when iterations are enabled' do
        before do
          stub_licensed_features(iterations: true)
          issue.update!(iteration: iteration)
        end

        shared_examples 'removes iteration' do |factory|
          let(:issuable) { create(factory, project: project, iteration: iteration) }

          it 'removes an assigned iteration' do
            _, updates, message = service.execute(content, issuable)

            expect(updates).to eq(iteration: nil)
            expect(message).to eq("Removed #{iteration.to_reference} iteration.")
          end
        end

        it_behaves_like 'removes iteration', :issue

        context 'when issuable is a work item' do
          it_behaves_like 'removes iteration', :work_item
        end

        context 'when issuable is an incident' do
          it_behaves_like 'removes iteration', :incident
        end

        context 'when the user does not have enough permissions' do
          before do
            allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
            allow(current_user).to receive(:can?).with(:admin_issue, project).and_return(false)
            allow(current_user).to receive(:can?).with(:admin_work_item, project).and_return(false)
          end

          let_it_be(:work_item_issue) { create(:work_item, :issue, project: project, iteration: iteration) }

          it 'returns an error message' do
            [issue, work_item_issue].each do |issuable|
              _, updates, message = service.execute(content, issuable)

              expect(updates).to be_empty
              expect(message).to eq('Could not apply remove_iteration command.')
            end
          end
        end
      end

      context 'when iterations are disabled' do
        before do
          stub_licensed_features(iterations: false)
        end

        it 'does not recognize /remove_iteration' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end
    end

    context 'set_parent command' do
      context 'on an issue' do
        let_it_be(:issue) { create(:issue, project: project) }

        context 'when epics are enabled' do
          before do
            stub_licensed_features(epics: true)
          end

          it 'allows the /set_parent command' do
            expect(service.available_commands(issue)).to include(a_hash_including(name: :set_parent))
          end
        end

        context 'when epics are disabled' do
          before do
            stub_licensed_features(epics: false)
          end

          it 'does not allow the /set_parent command' do
            expect(service.available_commands(issue)).not_to include(a_hash_including(name: :set_parent))
          end
        end
      end

      context 'on a work_item' do
        let_it_be(:work_item) { create(:work_item, :task, project: project) }

        it 'allows the /set_parent command' do
          expect(service.available_commands(work_item)).to include(a_hash_including(name: :set_parent))
        end
      end
    end

    context 'epic command' do
      context 'on an issue' do
        let_it_be_with_reload(:epic) { create(:epic, group: group) }
        let_it_be_with_reload(:private_epic) { create(:epic, group: create(:group, :private)) }
        let(:content) { "/epic #{epic.to_reference(project)}" }

        context 'when epics are enabled' do
          before do
            stub_licensed_features(epics: true)
          end

          context 'when epic exists' do
            it 'assigns an issue to an epic' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to eq(epic: epic)
              expect(message).to eq('Added an issue to an epic.')
            end

            context 'when it is confidential' do
              before do
                epic.update!(confidential: true)
                epic.sync_object.update!(confidential: true)
                group.add_developer(current_user)
              end

              it 'shows an error' do
                _, updates, message = service.execute(content, issue)

                expect(updates).to be_empty
                expect(message).to eq('Cannot assign a confidential parent item to a non-confidential child item. Make the child item confidential and try again.')
              end
            end

            context 'when an issue belongs to a project without group' do
              let_it_be(:user_project) { create(:project) }
              let(:issue)              { create(:issue, project: user_project) }

              before do
                user_project.add_guest(user)
              end

              it 'does not assign an issue to an epic' do
                _, updates = service.execute(content, issue)

                expect(updates).to be_empty
              end
            end

            context 'when issue is already added to epic' do
              it 'returns error message' do
                issue = create(:issue, project: project, epic: epic)
                WorkItem.find(issue.id).update!(work_item_parent: epic.sync_object)

                _, updates, message = service.execute(content, issue)

                expect(updates).to be_empty
                expect(message).to eq("#{issue.to_reference} has already been added to parent #{epic.sync_object.to_reference}.")
              end
            end

            context 'when issuable does not support epics' do
              it 'does not assign an incident to an epic' do
                incident = create(:incident, project: project)

                _, updates = service.execute(content, incident)

                expect(updates).to be_empty
              end
            end
          end

          context 'when epic does not exist' do
            let(:content) { "/epic none" }

            it 'does not assign an issue to an epic' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to be_empty
              expect(message).to eq("This parent item does not exist or you don't have sufficient permission.")
            end
          end

          context 'when user has no permissions to read epic' do
            let(:content) { "/epic #{private_epic.to_reference(project)}" }

            it 'does not assign an issue to an epic' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to be_empty
              expect(message).to eq("This parent item does not exist or you don't have sufficient permission.")
            end
          end

          context 'when user has no access to the issue' do
            before do
              allow(current_user).to receive(:can?).and_call_original
              allow(current_user).to receive(:can?).with(:admin_issue_relation, issue).and_return(false)
            end

            it 'returns error' do
              _, updates, message = service.execute(content, issue)

              expect(updates).to be_empty
              expect(message).to eq('Could not apply set_parent command.')
            end
          end
        end

        context 'when epics are disabled' do
          it 'does not recognize /epic' do
            _, updates = service.execute(content, issue)

            expect(updates).to be_empty
          end
        end
      end

      context 'on a work item' do
        let_it_be(:work_item_issue) { create(:work_item, :issue, project: project) }
        let_it_be(:epic) { create(:epic, :with_synced_work_item, group: group) }
        let(:content) { "/epic #{epic.to_reference}" }

        context 'when epics are enabled' do
          before do
            stub_licensed_features(epics: true)
          end

          context 'when epic exists' do
            it 'assigns an issue to an epic' do
              _, updates, message = service.execute(content, work_item_issue)

              expect(updates).to eq(set_parent: epic.sync_object)
              expect(message).to eq('Parent item set successfully.')
            end
          end
        end

        context 'when epics are disabled' do
          it 'does not recognize /epic' do
            _, updates = service.execute(content, work_item_issue)

            expect(updates).to be_empty
          end
        end
      end
    end

    context 'label command for epics' do
      let(:epic) { create(:epic, group: group) }
      let(:label) { create(:group_label, title: 'bug', group: group) }
      let(:project_label) { create(:label, title: 'project_label') }
      let(:content) { "/label ~#{label.title} ~#{project_label.title}" }

      let(:service) { described_class.new(container: group, current_user: current_user) }

      context 'when epics are enabled' do
        before do
          stub_licensed_features(epics: true)
        end

        context 'when a user has permissions to label an epic' do
          before do
            group.add_developer(current_user)
          end

          it 'populates valid label ids' do
            _, updates = service.execute(content, epic)

            expect(updates).to eq(add_label_ids: [label.id])
          end
        end

        context 'when a user does not have permissions to label an epic' do
          it 'does not populate any labels' do
            _, updates = service.execute(content, epic)

            expect(updates).to be_empty
          end
        end
      end

      context 'when epics are disabled' do
        it 'does not populate any labels' do
          group.add_developer(current_user)

          _, updates = service.execute(content, epic)

          expect(updates).to be_empty
        end
      end
    end

    context '/label command' do
      context 'when target is a group level work item' do
        let(:current_user) { developer }
        let_it_be(:new_group) { create(:group, developers: developer) }
        let_it_be(:group_level_work_item) { create(:work_item, :group_level, namespace: new_group) }

        let(:service) { described_class.new(container: group, current_user: current_user) }

        context 'with group level work items license' do
          before do
            stub_licensed_features(epics: true)
          end

          # This spec was introduced just to validate that the label finder scopes que query to a single group.
          # The command checks that labels are available as part of the condition.
          # Query was timing out in .com https://gitlab.com/gitlab-org/gitlab/-/issues/441123
          it 'is not available when there are no labels associated with the group' do
            expect(service.available_commands(group_level_work_item)).not_to include(a_hash_including(name: :label))
          end

          context 'when a label exists at the group level' do
            before do
              create(:group_label, group: group)
            end

            it 'is available' do
              expect(service.available_commands(group_level_work_item)).to include(a_hash_including(name: :label))
            end

            context 'without group level work items license' do
              before do
                stub_licensed_features(epics: false)
              end

              it 'is not available' do
                expect(service.available_commands(group_level_work_item)).not_to include(a_hash_including(name: :label))
              end
            end
          end
        end
      end
    end

    context 'remove_epic command' do
      let(:epic) { create(:epic, group: group) }
      let(:content) { "/remove_epic" }

      before do
        stub_licensed_features(epics: true)
        issue.update!(epic: epic)
      end

      context 'when epics are disabled' do
        before do
          stub_licensed_features(epics: false)
        end

        it 'does not recognize /remove_epic' do
          _, updates = service.execute(content, issue)

          expect(updates).to be_empty
        end
      end

      context 'when subepics are enabled' do
        before do
          stub_licensed_features(epics: true, subepics: true)
        end

        it 'unassigns an issue from an epic' do
          _, updates = service.execute(content, issue)

          expect(updates).to eq(epic: nil)
        end
      end

      context 'when user has no access to the issue' do
        before do
          allow(current_user).to receive(:can?).and_call_original
          allow(current_user).to receive(:can?).with(:admin_issue_relation, issue).and_return(false)
        end

        it 'returns error' do
          _, updates, message = service.execute(content, issue)

          expect(updates).to be_empty
          expect(message).to eq('Could not apply remove_epic command.')
        end
      end
    end

    context 'epic hierarchy commands' do
      it_behaves_like 'execute epic hierarchy commands'
    end

    context '/copy_metadata command' do
      let(:another_group) { build(:group) }

      before do
        stub_licensed_features(epics: true)
        another_group.add_planner(current_user)
        group.add_planner(current_user)
      end

      context "when a work item type epic is passed" do
        let(:todo_label) { create(:group_label, group: group, title: 'To Do') }
        let(:inreview_label) { create(:group_label, group: group, title: 'In Review') }
        let(:milestone) { create(:milestone, :on_group, group: group, title: '9.10') }
        let(:service) { described_class.new(container: group, current_user: current_user) }
        let(:source_issuable) do
          create(:work_item, :epic, namespace: group, milestone: milestone).tap do |wi|
            wi.labels << [todo_label, inreview_label]
          end
        end

        let(:content) { "/copy_metadata #{source_issuable.to_reference(group)}" }

        it_behaves_like 'copy_metadata command' do
          let(:issuable) { create(:work_item, namespace: group) }
        end

        it_behaves_like 'failed command' do
          let(:issuable) { create(:work_item, namespace: another_group) }
        end
      end
    end

    shared_examples 'weight command' do
      it 'populates weight specified by the /weight command' do
        _, updates = service.execute(content, issuable)

        expect(updates).to eq(weight: weight)
      end
    end

    shared_examples 'clear weight command' do
      it 'populates weight: nil if content contains /clear_weight' do
        issuable.update!(weight: 5)

        _, updates = service.execute(content, issuable)

        expect(updates).to eq(weight: nil)
      end

      it 'unsets weight if weight is 0' do
        issuable.update!(weight: 0)

        _, updates = service.execute(content, issuable)

        expect(updates).to eq(weight: nil)
      end
    end

    context 'issuable weights licensed' do
      let(:issuable) { issue }

      before do
        stub_licensed_features(issue_weights: true)
      end

      context 'weight' do
        let(:content) { "/weight #{weight}" }

        it_behaves_like 'weight command' do
          let(:weight) { 5 }
        end

        it_behaves_like 'weight command' do
          let(:weight) { 0 }
        end

        context 'when weight is negative' do
          it 'does not populate weight' do
            content = "/weight -10"
            _, updates = service.execute(content, issuable)

            expect(updates).to be_empty
          end
        end
      end

      context 'clear_weight' do
        it_behaves_like 'clear weight command' do
          let(:content) { '/clear_weight' }
        end
      end
    end

    context 'issuable weights unlicensed' do
      before do
        stub_licensed_features(issue_weights: false)
      end

      it 'does not recognise /weight X' do
        _, updates = service.execute('/weight 5', issue)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_weight' do
        _, updates = service.execute('/clear_weight', issue)

        expect(updates).to be_empty
      end
    end

    context 'issuable weights not supported by type' do
      let_it_be(:incident) { create(:incident, project: project) }

      before do
        stub_licensed_features(issue_weights: true)
      end

      it 'does not recognise /weight X' do
        _, updates = service.execute('/weight 5', incident)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_weight' do
        _, updates = service.execute('/clear_weight', incident)

        expect(updates).to be_empty
      end
    end

    shared_examples 'health_status command' do
      it 'populates health_status specified by the /health_status command' do
        _, updates = service.execute(content, issuable)

        expect(updates).to eq(health_status: health_status)
      end
    end

    shared_examples 'clear_health_status command' do
      it 'populates health_status: nil if content contains /clear_health_status' do
        issuable.update!(health_status: 'on_track')

        _, updates = service.execute(content, issuable)

        expect(updates).to eq(health_status: nil)
      end
    end

    context 'issuable health statuses licensed' do
      let(:issuable) { issue }

      before do
        stub_licensed_features(issuable_health_status: true)
      end

      context 'health_status' do
        let(:content) { "/health_status #{health_status}" }

        it_behaves_like 'health_status command' do
          let(:health_status) { 'on_track' }
        end

        it_behaves_like 'health_status command' do
          let(:health_status) { 'at_risk' }
        end

        context 'when health_status is invalid' do
          it 'does not populate health_status' do
            content = "/health_status unknown"
            _, updates = service.execute(content, issuable)

            expect(updates).to be_empty
          end
        end

        context 'when the user does not have enough permissions' do
          before do
            allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
            allow(current_user).to receive(:can?).with(:admin_issue, issuable).and_return(false)
          end

          it 'returns an error message' do
            content = "/health_status on_track"
            _, updates, message = service.execute(content, issuable)

            expect(updates).to be_empty
            expect(message).to eq('Could not apply health_status command.')
          end
        end
      end

      context 'clear_health_status' do
        it_behaves_like 'clear_health_status command' do
          let(:content) { '/clear_health_status' }
        end

        context 'when the user does not have enough permissions' do
          before do
            allow(current_user).to receive(:can?).with(:use_quick_actions).and_return(true)
            allow(current_user).to receive(:can?).with(:admin_issue, issuable).and_return(false)
          end

          it 'returns an error message' do
            content = "/clear_health_status"
            _, updates, message = service.execute(content, issuable)

            expect(updates).to be_empty
            expect(message).to eq('Could not apply clear_health_status command.')
          end
        end
      end
    end

    context 'issuable health_status unlicensed' do
      before do
        stub_licensed_features(issuable_health_status: false)
      end

      it 'does not recognise /health_status X' do
        _, updates = service.execute('/health_status needs_attention', issue)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_health_status' do
        _, updates = service.execute('/clear_health_status', issue)

        expect(updates).to be_empty
      end
    end

    context 'issuable health_status not supported by type' do
      let_it_be(:incident) { create(:incident, project: project) }

      before do
        stub_licensed_features(issuable_health_status: true)
      end

      it 'does not recognise /health_status X' do
        _, updates = service.execute('/health_status on_track', incident)

        expect(updates).to be_empty
      end

      it 'does not recognise /clear_health_status' do
        _, updates = service.execute('/clear_health_status', incident)

        expect(updates).to be_empty
      end
    end

    shared_examples 'empty command' do
      it 'populates {} if content contains an unsupported command' do
        _, updates = service.execute(content, issuable)

        expect(updates).to be_empty
      end
    end

    context 'not persisted merge request can not be merged' do
      it_behaves_like 'empty command' do
        let(:content) { "/merge" }
        let(:issuable) { build(:merge_request, source_project: project) }
      end
    end

    context 'not approved merge request can not be merged' do
      before do
        merge_request.target_project.update!(approvals_before_merge: 1)
      end

      it_behaves_like 'empty command' do
        let(:content) { "/merge" }
        let(:issuable) { build(:merge_request, source_project: project) }
      end
    end

    context 'when the merge request is not approved' do
      let!(:rule) { create(:any_approver_rule, merge_request: merge_request, approvals_required: 1) }
      let(:content) { '/merge' }

      context 'when "merge_when_checks_pass" is enabled' do
        let(:service) do
          described_class.new(
            container: project,
            current_user: current_user,
            params: { merge_request_diff_head_sha: merge_request.diff_head_sha }
          )
        end

        it 'runs merge command and returns merge message' do
          _, updates, message = service.execute(content, merge_request)

          expect(updates).to eq(merge: merge_request.diff_head_sha)

          expect(message).to eq('Set to auto-merge.')
        end
      end
    end

    context 'when the merge request is blocked' do
      let(:content) { '/merge' }
      let(:service) do
        described_class.new(
          container: project,
          current_user: current_user,
          params: { merge_request_diff_head_sha: issuable.diff_head_sha }
        )
      end

      let(:issuable) { create(:merge_request, :blocked, source_project: project) }

      before do
        stub_licensed_features(blocking_merge_requests: true)
      end

      it 'runs merge command and returns merge message' do
        _, updates, message = service.execute(content, issuable)

        expect(updates).to eq(merge: issuable.diff_head_sha)

        expect(message).to eq('Set to auto-merge.')
      end
    end

    context 'approved merge request can be merged' do
      before do
        merge_request.update!(approvals_before_merge: 1)
        merge_request.approvals.create!(user: current_user)
      end

      it_behaves_like 'empty command' do
        let(:content) { "/merge" }
        let(:issuable) { build(:merge_request, source_project: project) }
      end
    end

    context 'confidential command' do
      context 'for test cases' do
        it 'does mark to update confidential attribute' do
          issuable = create(:quality_test_case, project: project)

          _, updates, message = service.execute('/confidential', issuable)

          expect(message).to eq('Made this issue confidential.')
          expect(updates[:confidential]).to be(true)
        end
      end

      context 'for requirements' do
        it 'fails supports confidentiality condition' do
          issuable = create(:issue, :requirement, project: project)

          _, updates, message = service.execute('/confidential', issuable)

          expect(message).to eq('Could not apply confidential command.')
          expect(updates[:confidential]).to be_nil
        end
      end

      context 'for epics' do
        let_it_be_with_reload(:target_epic) { create(:epic, group: group) }
        let(:content) { '/confidential' }

        before do
          stub_licensed_features(epics: true)
          group.add_developer(current_user)
        end

        shared_examples 'command not applied' do
          it 'returns unsuccessful execution message' do
            _, updates, message = service.execute(content, target_epic)

            expect(message).to eq(execution_message)
            expect(updates[:confidential]).to be(true)
          end
        end

        it 'returns correct explain message' do
          _, explanations = service.explain(content, target_epic)

          expect(explanations).to match_array(['Makes this epic confidential.'])
        end

        it 'returns successful execution message' do
          _, updates, message = service.execute(content, target_epic)

          expect(message).to eq('Made this epic confidential.')
          expect(updates[:confidential]).to be(true)
        end

        context 'when epic has non-confidential issues' do
          before do
            target_epic.update!(confidential: false)
            issue.update!(confidential: false)
            create(:epic_issue, epic: target_epic, issue: issue)
          end

          it_behaves_like 'command not applied' do
            let_it_be(:execution_message) do
              'Cannot make the epic confidential if it contains non-confidential issues'
            end
          end
        end

        context 'when epic has non-confidential epics' do
          before do
            target_epic.update!(confidential: false)
            create(:epic, group: group, parent: target_epic, confidential: false)
          end

          it_behaves_like 'command not applied' do
            let_it_be(:execution_message) do
              'Cannot make the epic confidential if it contains non-confidential child epics'
            end
          end
        end

        context 'when a user has no permissions to set confidentiality' do
          before do
            group.add_guest(current_user)
          end

          it 'does not update epic confidentiality' do
            _, updates, message = service.execute(content, target_epic)

            expect(message).to eq('Could not apply confidential command.')
            expect(updates[:confidential]).to be_nil
          end
        end
      end
    end

    context 'blocking issues commands' do
      let(:user) { current_user }

      it_behaves_like 'issues link quick action', :blocks
      it_behaves_like 'issues link quick action', :blocked_by
    end

    context 'unlink command' do
      let_it_be(:unlink_target) { create(:issue, project: project) }
      let(:content) { "/unlink #{unlink_target.to_reference(issue)}" }
      let(:linked_item_reference) { unlink_target.to_reference(issue.project || issue.namespace) }
      let(:relation_reference) { unlink_target.to_reference }
      let(:source_reference) { issue.to_reference }

      subject(:unlink_issues) { service.execute(content, issue) }

      shared_examples 'command applied successfully' do
        it 'executes command successfully' do
          expect { unlink_issues }.to change { IssueLink.count }.by(-1)
          expect(unlink_issues[2]).to eq("Removed linked item #{linked_item_reference}.")
          expect(issue.notes.last.note).to eq("removed the relation with #{relation_reference}")
          expect(unlink_target.notes.last.note).to eq("removed the relation with #{source_reference}")
        end
      end

      context 'when command includes blocking issue' do
        before do
          create(:issue_link, source: unlink_target, target: issue, link_type: 'blocks')
        end

        it_behaves_like 'command applied successfully'
      end

      context 'when command includes blocked issue' do
        before do
          create(:issue_link, source: issue, target: unlink_target, link_type: 'blocks')
        end

        it_behaves_like 'command applied successfully'
      end

      context 'when target is not an issue' do
        let_it_be(:unlink_target) { create(:work_item, :epic, namespace: group) }
        let_it_be(:unlink_source) { create(:work_item, :epic, namespace: group) }
        let_it_be(:issue) { unlink_source }

        before do
          group.add_owner(current_user)
          stub_licensed_features(epics: true)

          create(:issue_link, source: unlink_source, target: unlink_target, link_type: 'relates_to')
        end

        it_behaves_like 'command applied successfully'
      end

      context 'when target is a legacy epic reference' do
        let_it_be(:unlink_target) { create(:epic, group: group) }
        let_it_be(:unlink_source) { create(:work_item, project: project) }
        let_it_be(:issue) { unlink_source }

        before do
          group.add_owner(current_user)
          stub_licensed_features(epics: true, related_epics: true)

          create(:work_item_link, source: unlink_source, target: unlink_target.work_item, link_type: 'relates_to')
        end

        it_behaves_like 'command applied successfully' do
          let(:linked_item_reference) { unlink_target.work_item.to_reference(issue) }
          let(:relation_reference) { unlink_target.work_item.to_reference(issue) }
          let(:source_reference) { issue.to_reference(issue) }
        end
      end

      context 'when provided issue is not linked' do
        it 'fails to execute command' do
          expect { unlink_issues }.not_to change { IssueLink.count }
          expect(unlink_issues[2]).to eq('No linked item matches the provided parameter.')
        end
      end
    end

    context 'blocking merge request commands' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let_it_be(:other_mr) { create(:merge_request, source_project: project, source_branch: 'other-branch') }

      before do
        stub_licensed_features(blocking_merge_requests: true)
      end

      describe '/blocks' do
        let(:content) { "/blocks #{other_mr.to_reference}" }

        it 'creates a blocking relationship' do
          expect { service.execute(content, merge_request) }
            .to change { MergeRequestBlock.count }.by(1)

          block = MergeRequestBlock.last
          expect(block.blocking_merge_request).to eq(merge_request)
          expect(block.blocked_merge_request).to eq(other_mr)
        end
      end

      describe '/blocked_by' do
        let(:content) { "/blocked_by #{other_mr.to_reference}" }

        it 'creates a blocked-by relationship' do
          expect { service.execute(content, merge_request) }
            .to change { MergeRequestBlock.count }.by(1)

          block = MergeRequestBlock.last
          expect(block.blocking_merge_request).to eq(other_mr)
          expect(block.blocked_merge_request).to eq(merge_request)
        end
      end

      describe '/unlink' do
        let(:content) { "/unlink #{other_mr.to_reference}" }

        context 'when merge requests have a blocking relationship' do
          before do
            create(:merge_request_block,
              blocking_merge_request: merge_request,
              blocked_merge_request: other_mr)
          end

          it 'removes the blocking relationship' do
            expect { service.execute(content, merge_request) }
              .to change { MergeRequestBlock.count }.by(-1)
          end
        end

        context 'when merge requests are not linked' do
          it 'returns failure message' do
            _, _, message = service.execute(content, merge_request)

            expect(message).to eq('No linked item matches the provided parameter.')
          end
        end
      end
    end

    describe 'status command' do
      shared_examples 'a failed command execution' do
        it 'fails with message' do
          _, updates, message = execute_command

          expect(message).to eq(expected_message)
          expect(updates).not_to have_key(:status)
        end
      end

      shared_examples 'command is not available' do
        it 'is not part of the available commands' do
          expect(service.available_commands(work_item)).not_to include(a_hash_including(name: :status))
        end
      end

      shared_examples 'status command execution' do
        let(:content) { '/status in progress' }
        let(:expected_message) { format(s_("WorkItemStatus|Status set to %{status_name}."), status_name: 'In progress') }
        let(:generic_error_message) { 'Could not apply status command.' }

        it 'is part of the available commands' do
          expect(service.available_commands(work_item)).to include(a_hash_including(name: :status))
        end

        it 'returns correct explain message' do
          _, explanations = service.explain(content, work_item)

          expect(explanations).to match_array([
            # Lower case version because we use status_name and not status object
            format(s_("WorkItemStatus|Set status to %{status_name}."), status_name: 'in progress')
          ])
        end

        it 'adds status reference to updates with message' do
          _, updates, message = execute_command

          expect(message).to eq(expected_message)
          expect(updates[:status]).to have_attributes(expected_status_attributes)
        end

        context 'when name has whitespace' do
          let(:content) { '/status  in progress  ' }

          it 'adds status reference to updates with message' do
            _, updates, message = execute_command

            expect(message).to eq(expected_message)
            expect(updates[:status]).to have_attributes(expected_status_attributes)
          end
        end

        context 'when name has surrounding quotes' do
          let(:content) { '/status "in progress"' }

          it 'adds status reference to updates with message' do
            _, updates, message = execute_command

            expect(message).to eq(expected_message)
            expect(updates[:status]).to have_attributes(expected_status_attributes)
          end
        end

        context 'when status name does not reference a valid status' do
          let(:content) { '/status invalid' }
          let(:expected_message) do
            format(
              s_("WorkItemStatus|%{status_name} is not a valid status for this item."),
              { status_name: 'invalid' }
            )
          end

          it_behaves_like 'a failed command execution'
        end

        context 'when status widget is not available for work item type' do
          let_it_be_with_reload(:work_item) { create(:work_item, :ticket, project: project) }
          let(:expected_message) { generic_error_message }

          it_behaves_like 'command is not available'
          it_behaves_like 'a failed command execution'
        end

        context 'when work_item_status licensed feature is disabled' do
          let(:expected_message) { generic_error_message }

          before do
            stub_licensed_features(work_item_status: false)
          end

          it_behaves_like 'command is not available'
          it_behaves_like 'a failed command execution'
        end
      end

      let_it_be_with_reload(:work_item) { create(:work_item, :task, project: project) }

      subject(:execute_command) { service.execute(content, work_item) }

      before do
        stub_licensed_features(work_item_status: true)
      end

      context 'with system-defined statuses' do
        let(:expected_status_attributes) { { id: 2, name: 'In progress' } }

        it_behaves_like 'status command execution'
      end

      context 'with custom statuses' do
        let_it_be(:custom_status_to_do) { create(:work_item_custom_status, :to_do, name: 'To do', namespace: group) }
        let_it_be(:custom_status_in_progress) do
          create(:work_item_custom_status, :in_progress, name: 'In progress', namespace: group)
        end

        let_it_be_with_reload(:work_item) do
          create(:work_item, :task, custom_status_id: custom_status_to_do.id, project: project)
        end

        let(:expected_status_attributes) { { id: custom_status_in_progress.id, name: 'In progress' } }

        it_behaves_like 'status command execution'

        context 'when status name references a system-defined status' do
          let(:content) { '/status done' }
          let(:expected_message) do
            format(
              s_("WorkItemStatus|%{status_name} is not a valid status for this item."),
              { status_name: 'done' }
            )
          end

          it_behaves_like 'a failed command execution'
        end
      end
    end

    it_behaves_like 'quick actions that change work item type ee'

    context 'with scope_validator' do
      let(:scope_validator) { instance_double(Gitlab::Auth::ScopeValidator) }
      let(:service) do
        described_class.new(container: project, current_user: current_user, params: { scope_validator: scope_validator })
      end

      context 'when permit_quick_actions? is true' do
        let(:scope_validator) { instance_double(Gitlab::Auth::ScopeValidator, permit_quick_actions?: true) }

        it 'allows quick actions' do
          expect do
            service.execute('/label ~bug', issue)
          end.not_to raise_error
        end
      end

      context 'when permit_quick_actions? is false' do
        let(:scope_validator) { instance_double(Gitlab::Auth::ScopeValidator, permit_quick_actions?: false) }

        it 'does not raise if no quick actions are present' do
          expect do
            service.execute('Just a regular comment', issue)
          end.not_to raise_error
        end

        context 'with allowed quick actions' do
          # `freeze: false` is required in this spec: one or more `let_it_be` subjects
          # cannot be frozen by default (deep_freeze traversal failure, a non-AR
          # subject, or an in-memory mutation that survives reload/refind). Do not
          # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
          # (see gitlab-org/gitlab#602925).
          let_it_be(:cadence, freeze: false) { create(:iterations_cadence, group: group) }
          let_it_be(:iteration, freeze: false) { create(:iteration, iterations_cadence: cadence) }

          # Each allowed action must be exercised against a target that actually recognizes
          # the command. If a command is unrecognized for the target the commands list is
          # empty, quick_actions_check_not_needed? returns true and the test passes trivially.
          before do
            stub_licensed_features(
              multiple_issue_assignees: true,
              multiple_merge_request_reviewers: true,
              multiple_merge_request_assignees: true,
              issue_weights: true,
              issuable_health_status: true,
              iterations: true
            )

            # /clear_weight, /clear_health_status and /remove_iteration are only recognized
            # when the issue already has a value set, otherwise their conditions exclude them.
            issue.update!(weight: 3, health_status: :on_track, iteration: iteration)
          end

          where(:content) do
            [
              ['/label ~bug'],
              ['/unlabel ~bug'],
              ['/relabel ~bug'],
              ['/title New title'],
              [lazy { "/assign @#{current_user.username}" }],
              ['/unassign'],
              [lazy { "/reassign @#{current_user.username}" }],
              ['/milestone %v1.0'],
              ['/remove_milestone'],
              ['/due tomorrow'],
              ['/remove_due_date'],
              ['/estimate 1d'],
              ['/remove_estimate'],
              ['/spend 1d'],
              ['/remove_time_spent'],
              ['/weight 5'],
              ['/clear_weight'],
              ['/health_status on_track'],
              ['/clear_health_status'],
              [lazy { "/iteration #{iteration.to_reference}" }],
              ['/remove_iteration']
            ]
          end

          with_them do
            it 'does not raise' do
              expect { service.execute(content, issue) }.not_to raise_error
            end
          end

          # MR-only allowed actions must be tested against a merge_request target;
          # using an issue would cause the command to be unrecognized (empty commands list),
          # making quick_actions_check_not_needed? return true and the test pass trivially.
          where(:content) do
            [
              [lazy { "/reviewer @#{current_user.username}" }],
              ['/unassign_reviewer'],
              [lazy { "/reassign_reviewer @#{current_user.username}" }],
              ['/draft'],
              ['/ready']
            ]
          end

          with_them do
            it 'does not raise for MR-only allowed actions' do
              expect { service.execute(content, merge_request) }.not_to raise_error
            end
          end
        end

        context 'with blocked quick actions' do
          where(:action, :expected_name) do
            [
              ['/close',  'close'],
              ['/reopen', 'reopen']
            ]
          end

          with_them do
            it 'raises QuickActionsNotAllowedError' do
              expect do
                service.execute(action, issue)
              end.to raise_error(
                QuickActions::InterpretService::QuickActionsNotAllowedError,
                "Quick actions #{expected_name} cannot be used with AI workflows."
              )
            end
          end

          it 'raises listing only the blocked actions when mixed with allowed ones' do
            expect do
              service.execute("/close\n/label ~bug", issue)
            end.to raise_error(
              QuickActions::InterpretService::QuickActionsNotAllowedError,
              'Quick actions close cannot be used with AI workflows.'
            )
          end

          it 'raises listing all blocked actions when multiple blocked actions are used' do
            expect do
              service.execute("/close\n/reopen", issue)
            end.to raise_error(
              QuickActions::InterpretService::QuickActionsNotAllowedError,
              a_string_including('close').and(include('reopen')).and(include('cannot be used with AI workflows'))
            )
          end
        end
      end
    end

    describe '#blocked_ai_quick_actions' do
      let(:scope_validator) { instance_double(Gitlab::Auth::ScopeValidator, permit_quick_actions?: false) }
      let(:service) do
        described_class.new(container: project, current_user: current_user, params: { scope_validator: scope_validator })
      end

      context 'with every action in the allowlist' do
        # definition_by_name looks up commands by name in a static hash and does not
        # evaluate condition blocks, so EE-only commands like :status are returned
        # unconditionally regardless of licensed feature availability.
        where(:command) { EE::QuickActions::InterpretService::ALLOWED_AI_QUICK_ACTIONS.map { |c| [c] } }

        with_them do
          it 'is not blocked' do
            expect(service.send(:blocked_ai_quick_actions, [command])).to be_empty
          end
        end
      end

      it 'returns blocked commands that are not in the allowlist' do
        # :close is not in ALLOWED_AI_QUICK_ACTIONS
        expect(service.send(:blocked_ai_quick_actions, [:close])).to eq([:close])
      end

      it 'returns only the blocked commands when mixed with allowed ones' do
        expect(service.send(:blocked_ai_quick_actions, [:label, :close])).to eq([:close])
      end

      it 'treats commands with no matching definition as blocked (safe default)' do
        # An unrecognized command name has no definition, so it is treated as blocked
        expect(service.send(:blocked_ai_quick_actions, [:nonexistent_command])).to eq([:nonexistent_command])
      end

      it 'resolves aliases to their canonical definition for the allowlist check' do
        # :labels is an alias for :label, which is in ALLOWED_AI_QUICK_ACTIONS
        expect(service.send(:blocked_ai_quick_actions, [:labels])).to be_empty
      end
    end
  end

  describe '#explain' do
    describe 'health_status command' do
      let(:content) { '/health_status on_track' }

      context 'issuable health statuses licensed' do
        before do
          stub_licensed_features(issuable_health_status: true)
        end

        it 'includes the value' do
          _, explanations = service.explain(content, issue)
          expect(explanations).to eq(['Sets health status to on_track.'])
        end
      end
    end

    describe 'epic command' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'for an issue' do
        let(:issue) { create(:issue, project: project) }
        let(:epic) { create(:epic, group: project.group) }

        let(:content) { "/epic #{epic.to_reference}" }

        it 'applies the correct explanation' do
          _, explanations = service.explain(content, issue)
          expect(explanations).to eq(["Set #{epic.to_reference} as this item's parent item."])
        end
      end

      context 'for a work_item' do
        let(:issue_work_item) { create(:work_item, :issue, project: project) }
        let(:epic_work_item) { create(:work_item, :epic, namespace: project.group) }

        let(:content) { "/epic #{epic_work_item.to_reference}" }

        it 'applies the correct explanation' do
          _, explanations = service.explain(content, issue_work_item)
          expect(explanations).to eq(["Set #{epic_work_item.to_reference} as this item's parent item."])
        end
      end
    end

    describe 'milestone command' do
      context 'on group-level work items' do
        let_it_be(:group_milestone) { create(:milestone, group: group, title: 'Group Milestone') }
        let_it_be(:group_work_item) { create(:work_item, :epic, :group_level, namespace: group) }
        # `freeze: false` is required in this spec: one or more `let_it_be` subjects
        # cannot be frozen by default (deep_freeze traversal failure, a non-AR
        # subject, or an in-memory mutation that survives reload/refind). Do not
        # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
        # (see gitlab-org/gitlab#602925).
        let_it_be(:group_service, freeze: false) { described_class.new(container: group, current_user: developer) }

        before_all do
          group.add_developer(developer)
        end

        before do
          stub_licensed_features(epics: true)
        end

        it 'includes the milestone command in available commands for group level work items' do
          expect(group_service.available_commands(group_work_item)).to include(a_hash_including(name: :milestone))
        end

        it 'updates the milestone on a group level work item' do
          _, updates, _ = group_service.execute("/milestone %\"#{group_milestone.title}\"", group_work_item)

          expect(updates).to eq(milestone_id: group_milestone.id)
        end
      end
    end

    describe 'unassign command' do
      let(:content) { '/unassign' }
      let(:issue) { create(:issue, project: project, assignees: [user, user2]) }

      it "includes all assignees' references" do
        _, explanations = service.explain(content, issue)

        expect(explanations).to eq(["Removes assignees @#{user.username} and @#{user2.username}."])
      end
    end

    describe 'unassign command with assignee references' do
      let(:content) { "/unassign @#{user.username} @#{user3.username}" }
      let(:issue) { create(:issue, project: project, assignees: [user, user2, user3]) }

      it 'includes only selected assignee references' do
        _, explanations = service.explain(content, issue)

        expect(explanations.first).to match(/Removes assignees/)
        expect(explanations.first).to match("@#{user3.username}")
        expect(explanations.first).to match("@#{user.username}")
      end
    end

    describe 'weight command' do
      let(:content) { '/weight 4' }

      it 'includes the number' do
        _, explanations = service.explain(content, issue)
        expect(explanations).to eq(['Sets weight to 4.'])
      end

      context 'for a work item type that does not support weight' do
        let_it_be(:target) { create(:work_item, :epic, :group_level, namespace: group) }

        it_behaves_like 'quick action is unavailable', :weight

        it '/weight explain message is not available' do
          _, explanations = service.explain(content, target)

          expect(explanations).to be_empty
        end
      end
    end

    describe 'linked items commands' do
      let_it_be(:guest) { create(:user) }
      let_it_be(:restricted_project) { create(:project) }
      let_it_be(:ref1) { create(:issue, project: project).to_reference }
      let_it_be(:ref2) { create(:issue, project: project).to_reference }
      let_it_be(:ref3) { create(:work_item, project: project).to_reference }
      let_it_be(:ref4) { create(:work_item, :epic, namespace: group).to_reference }
      let_it_be(:ref5) { create(:work_item, :epic_with_legacy_epic, namespace: group).to_reference(full: true) }

      let(:target) { issue }

      before do
        issue.project.add_guest(guest)
      end

      context 'with /blocks' do
        let(:blocks_command) { "/blocks #{ref1} #{ref2} #{ref3} #{ref4}" }

        context 'with sufficient permissions' do
          before do
            issue.project.add_developer(current_user)
          end

          it '/blocks is available' do
            _, explanations = service.explain(blocks_command, issue)

            expect(explanations).to contain_exactly("Set this issue as blocking #{[ref1, ref2, ref3, ref4].to_sentence}.")
          end

          context 'with task as target' do
            let_it_be(:task) { create(:work_item, :task, project: project) }
            let(:target) { task }

            it 'replaces issue in explanation with task' do
              _, explanations = service.explain(blocks_command, task)

              expect(explanations).to contain_exactly("Set this task as blocking #{[ref1, ref2, ref3, ref4].to_sentence}.")
            end
          end

          context 'when licensed feature is not available' do
            before do
              stub_licensed_features(blocked_issues: false)
            end

            it_behaves_like 'quick action is unavailable', :blocks
          end

          context 'when target is not an issue' do
            let(:target) { create(:epic, group: group) }

            it_behaves_like 'quick action is unavailable', :blocks
          end
        end

        context 'with insufficient permissions' do
          let_it_be(:target) { create(:issue, project: restricted_project) }
          let(:current_user) { guest }

          it_behaves_like 'quick action is unavailable', :blocks
        end
      end

      context 'with /relate' do
        let(:relate_command) { "/relate #{ref1} #{ref2} #{ref3} #{ref4}" }

        context 'with sufficient permissions' do
          before do
            issue.project.add_developer(current_user)
          end

          it '/relate is available' do
            _, explanations = service.explain(relate_command, issue)

            expect(explanations).to contain_exactly(
              "Added #{[ref1, ref2, ref3, ref4].to_sentence} as a linked item related to this issue."
            )
          end

          it '/relate execution method' do
            _, _, message = service.execute(relate_command, issue)

            expect(message).to eq(
              "Added #{[ref1, ref2, ref3, ref4].to_sentence} as a linked item related to this issue."
            )
          end

          context 'when target is not an issue' do
            let(:target) { create(:epic, group: group) }

            it_behaves_like 'quick action is unavailable', :relate
          end

          context 'when target is a work item epic with a legacy epic' do
            let(:target) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
            let(:relate_command) { "/relate #{ref5}" }

            before do
              group.add_developer(current_user)
              stub_licensed_features(epics: true, related_epics: true)
            end

            it '/relate execution method' do
              expect { service.execute(relate_command, target) }
                .to change { IssueLink.count }.by(1)
                .and change { Epic::RelatedEpicLink.count }.by(1)
            end
          end
        end

        context 'with insufficient permissions' do
          let_it_be(:target) { create(:issue, project: restricted_project) }
          let(:current_user) { guest }

          it_behaves_like 'quick action is unavailable', :relate
        end
      end

      context 'with /unlink' do
        let(:unlink_command) { "/unlink #{ref1}" }

        context 'with sufficient permissions' do
          before do
            issue.project.add_guest(current_user)
          end

          it '/unlink is available' do
            _, explanations = service.explain(unlink_command, issue)

            expect(explanations)
              .to contain_exactly("Removes linked item #{project.issues.second.to_reference(project)}.")
          end

          context 'when target is not an issue' do
            let(:target) { create(:epic, group: group) }

            it_behaves_like 'quick action is unavailable', :unlink
          end
        end

        context 'with insufficient permissions' do
          let_it_be(:target) { create(:issue, project: restricted_project) }
          let(:current_user) { guest }

          it_behaves_like 'quick action is unavailable', :blocks
        end
      end

      context 'with /blocked_by' do
        let(:blocked_by_command) { "/blocked_by #{ref1} #{ref2} #{ref3} #{ref4}" }

        context 'with sufficient permissions' do
          before do
            issue.project.add_guest(current_user)
          end

          it '/blocked_by is available' do
            _, explanations = service.explain(blocked_by_command, issue)

            expect(explanations)
              .to contain_exactly("Set this issue as blocked by #{[ref1, ref2, ref3, ref4].to_sentence}.")
          end

          context 'when licensed feature is not available' do
            before do
              stub_licensed_features(blocked_issues: false)
            end

            it_behaves_like 'quick action is unavailable', :blocked_by
          end

          context 'when target is not an issue' do
            let(:target) { create(:epic, group: group) }

            it_behaves_like 'quick action is unavailable', :blocked_by
          end
        end

        context 'with insufficient permissions' do
          let_it_be(:target) { create(:issue, project: restricted_project) }
          let(:current_user) { guest }

          it_behaves_like 'quick action is unavailable', :blocked_by
        end
      end
    end

    describe 'promote_to command' do
      let(:content) { '/promote_to objective' }

      context 'when work item supports promotion' do
        context 'with key result' do
          let_it_be(:key_result) { build(:work_item, :key_result, project: project) }

          it 'includes the value' do
            _, explanations = service.explain(content, key_result)
            expect(explanations).to eq(['Promotes item to objective.'])
          end
        end

        context 'with issue' do
          let_it_be(:issue) { build(:work_item, :issue, project: project) }

          where(type: %w[incident epic])

          with_them do
            it 'includes the type in the explanation' do
              _, explanations = service.explain("/promote_to #{type}", issue)
              expect(explanations).to eq(["Promotes item to #{type}."])
            end
          end
        end
      end

      context 'when work item does not support promotion' do
        let_it_be(:requirement) { build(:work_item, :requirement, project: project) }

        it 'does not include the value' do
          _, explanations = service.explain(content, requirement)
          expect(explanations).to be_empty
        end
      end
    end

    describe 'checkin_reminder command' do
      let(:checkin_reminder_command) { "/checkin_reminder weekly" }

      context 'for a work item type that supports reminders' do
        let(:objective) { create(:work_item, :objective, project: project, author: current_user) }

        it '/checkin_reminder is available' do
          _, explanations = service.explain(checkin_reminder_command, objective)

          expect(explanations).to contain_exactly("Sets checkin reminder frequency to weekly.")
        end
      end

      context 'for a work item type that does not support reminders' do
        let(:key_result) { create(:work_item, :key_result, project: project) }

        it '/checkin_reminder is available' do
          _, explanations = service.explain(checkin_reminder_command, key_result)

          expect(explanations).not_to contain_exactly("Sets checkin reminder frequency to weekly.")
        end
      end
    end

    describe 'epic hierarchy commands' do
      it_behaves_like 'explain epic hierarchy commands'
    end
  end

  context '/duplicate command' do
    before do
      stub_licensed_features(epics: true)
      group.add_developer(current_user)
    end

    context 'when canonical item is an epic' do
      let(:duplicate_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

      context 'when epic work item' do
        context 'with reference' do
          it_behaves_like 'duplicate command' do
            let(:content) { "/duplicate #{duplicate_item.to_reference(project, full: true)}" }
            let(:issuable) { issue }
          end
        end

        context 'with url' do
          it_behaves_like 'duplicate command' do
            let(:content) { "/duplicate #{Gitlab::UrlBuilder.build(duplicate_item)}" }
            let(:issuable) { issue }
          end
        end
      end

      context 'when legacy epic' do
        context 'with reference' do
          it_behaves_like 'duplicate command' do
            let(:content) { "/duplicate #{duplicate_item.sync_object.to_reference(project, full: true)}" }
            let(:issuable) { issue }
          end
        end

        context 'with url' do
          it_behaves_like 'duplicate command' do
            let(:content) { "/duplicate #{Gitlab::UrlBuilder.build(duplicate_item.sync_object)}" }
            let(:issuable) { issue }
          end
        end
      end
    end

    context 'when duplicate item is an epic work item' do
      let(:canonical_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }
      let(:duplicate_item) { issue }

      let(:service) { described_class.new(container: group, current_user: current_user) }

      context 'with reference' do
        it_behaves_like 'duplicate command' do
          let(:content) { "/duplicate #{duplicate_item.to_reference(group)}" }
          let(:issuable) { canonical_item }
        end
      end

      context 'with url' do
        it_behaves_like 'duplicate command' do
          let(:content) { "/duplicate #{Gitlab::UrlBuilder.build(duplicate_item)}" }
          let(:issuable) { canonical_item }
        end
      end
    end
  end

  describe 'clone issue command' do
    let(:content) { "/clone #{group.full_path}" }
    let(:group_service) { described_class.new(container: group, current_user: current_user) }
    let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

    before do
      group.add_maintainer(current_user)
      stub_licensed_features(epics: true)
    end

    context "when work item type is an epic" do
      it "/clone is available" do
        _, explanations = group_service.explain(content, work_item)

        expected_string = "Clones this item, without comments, to #{group.full_path}."
        expect(explanations).to match_array([_(expected_string)])
      end

      it "recognizes the clone action when move and clone commands are supported" do
        expect(service.available_commands(work_item).pluck(:name)).to include(:clone)
      end

      it "does not recognize the clone action when move and clone commands are not supported" do
        allow(work_item).to receive(:supports_move_and_clone?).and_return(false)
        expect(service.available_commands(work_item).pluck(:name)).not_to include(:clone)
      end

      it 'returns the clone item message' do
        _, _, message = service.execute("/clone #{group.full_path}", work_item)
        translated_string = _("Cloned this item to %{group_full_path}.")
        formatted_message = format(translated_string, group_full_path: group.full_path.to_s)

        expect(message).to  eq(formatted_message)
      end

      it 'returns clone item failure message when the referenced group is not found' do
        _, _, message = service.execute('/clone invalid', work_item)

        expect(message).to eq(_("Unable to clone. Target project or group doesn't exist or doesn't support this item type."))
      end

      it 'returns clone item failure message when the path provided is to a project' do
        _, _, message = service.execute("/clone #{project.full_path}", work_item)

        expect(message).to eq(_("Unable to clone. Target project or group doesn't exist or doesn't support this item type."))
      end

      it 'returns clone item failure message when the referenced group not authorized' do
        _, _, message = service.execute("/clone #{create(:group).full_path}", work_item)

        expect(message).to eq(_("Unable to clone. Insufficient permissions."))
      end
    end
  end

  describe '/move issue command' do
    let(:target_group) { create(:group, :public) }
    let(:content) { "/move #{target_group.full_path}" }
    let(:group_service) { described_class.new(container: group, current_user: current_user) }
    let_it_be(:work_item) { create(:work_item, :epic_with_legacy_epic, :group_level, namespace: group) }

    before do
      group.add_maintainer(current_user)
      target_group.add_maintainer(current_user)
      stub_licensed_features(epics: true)
    end

    context "when work item type is epic" do
      it "/move is available" do
        _, explanations = group_service.explain(content, work_item)

        expected_string = "Moves this item to #{target_group.full_path}."
        expect(explanations).to match_array([_(expected_string)])
      end

      it 'recognizes the move action when move and clone is supported' do
        expect(service.available_commands(work_item).pluck(:name)).to include(:move)
      end

      it "does not recognize the move action when move and clone commands are not supported" do
        allow(work_item).to receive(:supports_move_and_clone?).and_return(false)
        expect(service.available_commands(work_item).pluck(:name)).not_to include(:move)
      end

      it "returns the move item message" do
        _, _, message = service.execute(content, work_item)
        translated_string = _("Moved this item to %{group_full_path}.")
        formatted_message = format(translated_string, group_full_path: target_group.full_path.to_s)

        expect(message).to  eq(formatted_message)
      end

      it "returns move item failure message when target group is not found" do
        _, _, message = service.execute('/move invalid', work_item)

        expect(message).to eq(_("Unable to move. Target project or group doesn't exist or doesn't support this item type."))
      end

      it "returns move item failure message when the path provided is to a project" do
        _, _, message = service.execute("/move #{project.full_path}", work_item)

        expect(message).to eq(_("Unable to move. Target project or group doesn't exist or doesn't support this item type."))
      end

      it 'returns move item failure message when the referenced group not authorized' do
        _, _, message = service.execute("/move #{create(:group).full_path}", work_item)

        expect(message).to eq(_("Unable to move. Insufficient permissions."))
      end
    end
  end

  describe 'resolving the target work item type for /move and /clone' do
    let_it_be(:source_group) { create(:group) }
    let_it_be(:target_group) { create(:group) }
    let_it_be(:source_project) { create(:project, group: source_group) }
    let_it_be(:target_project) { create(:project, group: target_group) }

    let(:source_type) do
      create(:work_item_custom_type, namespace: source_group, name: 'Feature')
    end

    # Assign the custom type via `update_column` because the factory's
    # `work_item_type=` setter runs before `namespace` is set from `project`,
    # so the provider can't resolve a custom type at build time and falls back
    # to the default Issue type.
    let(:source_item) do
      work_item = create(:work_item, project: source_project)
      work_item.update_column(:work_item_type_id, source_type.persistable_id)
      WorkItem.find(work_item.id)
    end

    let(:service) { described_class.new(container: source_project, current_user: current_user) }

    before do
      stub_licensed_features(epics: true, configurable_work_item_types: true)
      stub_saas_features(namespace_scoped_work_item_types: true)

      source_project.add_maintainer(current_user)
      target_project.add_maintainer(current_user)
    end

    shared_examples 'target work item type resolution' do |action, container_key|
      context 'when an explicit type that exists at the destination is supplied' do
        let_it_be(:destination_type) do
          create(:work_item_custom_type, namespace: target_group, name: 'Bug')
        end

        it 'converts the item to that destination type', :aggregate_failures do
          _, updates, message = service.execute(
            "/#{action} #{target_project.full_path} [type:#{destination_type.name}]", source_item
          )

          expect(message).to include("#{action.capitalize}d this item")
          expect(updates[container_key]).to eq(target_project)
          expect(updates[:target_work_item_type_id]).to eq(destination_type.id)
        end
      end

      context 'when no type is supplied and the source type exists at the destination by id' do
        let_it_be(:system_source_type) { build(:work_item_system_defined_type, :issue) }

        let_it_be_with_reload(:system_source_item) do
          create(:work_item, project: source_project, work_item_type: system_source_type)
        end

        it 'uses the equivalent destination type', :aggregate_failures do
          _, updates, message = service.execute("/#{action} #{target_project.full_path}", system_source_item)

          expect(message).to include("#{action.capitalize}d this item")
          expect(updates[container_key]).to eq(target_project)
          expect(updates[:target_work_item_type_id]).to eq(system_source_type.id)
        end
      end

      context 'when no type is supplied and the source type does not exist at the destination' do
        let_it_be(:other_type) { create(:work_item_custom_type, namespace: target_group, name: 'Other') }

        it 'fails and lists the available types in the target namespace', :aggregate_failures do
          _, updates, message = service.execute("/#{action} #{target_project.full_path}", source_item)

          expect(message).to start_with(
            "Unable to #{action}. The source work item type \"#{source_type.name}\" is not available in " \
              "the target namespace. Specify one using `[type:NAME]`."
          )
          expect(message).to include('Available types:')
          expect(message).to include(other_type.name)
          expect(updates).not_to have_key(container_key)
          expect(updates).not_to have_key(:target_work_item_type_id)
        end
      end

      context 'when the explicit type is not available at the destination' do
        let_it_be(:destination_type) { create(:work_item_custom_type, namespace: target_group, name: 'Bug') }

        it 'fails and lists the available types in the target namespace', :aggregate_failures do
          _, updates, message = service.execute(
            "/#{action} #{target_project.full_path} [type:DoesNotExist]", source_item
          )

          expect(message).to start_with(
            "Unable to #{action}. The work item type \"DoesNotExist\" is not available in the target namespace."
          )
          expect(message).to include('Available types:')
          expect(message).to include(destination_type.name)
          expect(updates).not_to have_key(container_key)
          expect(updates).not_to have_key(:target_work_item_type_id)
        end
      end

      context 'when an explicit multi-word type is supplied' do
        let_it_be(:multi_word_type) do
          create(:work_item_custom_type, namespace: target_group, name: 'Key Feature')
        end

        it 'accepts the value without quoting (terminated by `]`)', :aggregate_failures do
          _, updates, message = service.execute(
            "/#{action} #{target_project.full_path} [type:#{multi_word_type.name}]", source_item
          )

          expect(message).to include("#{action.capitalize}d this item")
          expect(updates[container_key]).to eq(target_project)
          expect(updates[:target_work_item_type_id]).to eq(multi_word_type.id)
        end
      end

      context 'when an explicit type exists at the destination but is disabled there' do
        # A namespace-disabled type is still returned by `Provider#all`, but its
        # `enabled?` flag is false. The quick action must reject it instead of
        # silently letting the data sync fail (or succeed with a disabled type).
        let_it_be(:disabled_type) { create(:work_item_custom_type, namespace: target_group, name: 'DisabledBug') }

        let_it_be(:enabled_type) { create(:work_item_custom_type, namespace: target_group, name: 'EnabledFeature') }

        before do
          create(:work_item_settings, namespace: target_group, customizable_type_visibility: true)
          create(
            :work_item_type_visibility,
            namespace: target_group,
            work_item_type_id: disabled_type.id,
            enabled: false,
            propagate: true
          )
        end

        it 'fails with a disabled-type message and does not apply the type', :aggregate_failures do
          _, updates, message = service.execute(
            "/#{action} #{target_project.full_path} [type:#{disabled_type.name}]", source_item
          )

          expect(message).to start_with(
            "Unable to #{action}. The work item type \"#{disabled_type.name}\" is disabled in the target namespace."
          )
          expect(message).to include('Available types:')
          expect(message).to include(enabled_type.name)
          expect(message).not_to include("#{disabled_type.name},")
          expect(updates).not_to have_key(container_key)
          expect(updates).not_to have_key(:target_work_item_type_id)
        end
      end
    end

    it_behaves_like 'target work item type resolution', 'move', :target_container
    it_behaves_like 'target work item type resolution', 'clone', :target_clone_container
  end
end
