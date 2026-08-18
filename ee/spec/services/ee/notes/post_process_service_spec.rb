# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Notes::PostProcessService, feature_category: :team_planning do
  describe '#execute' do
    context 'analytics' do
      subject { described_class.new(note) }

      let(:note) { create(:note) }
      let(:analytics_mock) { instance_double('Analytics::RefreshCommentsData') }

      it 'invokes Analytics::RefreshCommentsData' do
        allow(Analytics::RefreshCommentsData).to receive(:for_note).with(note).and_return(analytics_mock)

        expect(analytics_mock).to receive(:execute)

        subject.execute
      end
    end

    context 'for audit events' do
      subject(:notes_post_process_service) { described_class.new(note) }

      context 'when note author is a project bot' do
        let_it_be(:project_bot) { create(:user, :project_bot, email: "bot@example.com") }

        let(:note) { create(:note, author: project_bot) }

        it 'audits with correct name' do
          # Stub .audit here so that only relevant audit events are received below
          allow(::Gitlab::Audit::Auditor).to receive(:audit)

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(name: "comment_by_project_bot", stream_only: true)
          ).and_call_original

          notes_post_process_service.execute
        end

        it 'does not persist the audit event to database' do
          expect { notes_post_process_service.execute }.not_to change { AuditEventReader.count }
        end
      end

      context 'when note author is not a project bot' do
        let(:note) { create(:note) }

        it 'does not invoke Gitlab::Audit::Auditor' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including(
            name: 'comment_by_project_bot'
          ))

          notes_post_process_service.execute
        end

        it 'does not create an audit event' do
          expect { notes_post_process_service.execute }.not_to change { AuditEventReader.count }
        end
      end

      context 'with human authored note' do
        let(:note) { create(:note) }

        it 'audits with comment_created event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'comment_created',
              target: note,
              additional_details: {
                body: note.note
              },
              stream_only: true
            )
          ).and_call_original

          notes_post_process_service.execute
        end

        context 'when note is on a personal snippet' do
          let!(:note) { create(:note_on_personal_snippet) }

          it 'does not audit the event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
              hash_including(name: 'comment_created')
            )

            notes_post_process_service.execute
          end
        end

        context 'when note is a system note' do
          let(:note) { create(:note, :system) }

          it 'does not audit the event' do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(
              hash_including(name: 'comment_created')
            )

            notes_post_process_service.execute
          end
        end
      end
    end

    context 'for processing Duo Code Review chat' do
      let_it_be(:project) { create(:project, :repository) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
      let_it_be(:note) { create(:diff_note_on_merge_request, noteable: merge_request, project: project) }

      subject(:execute) { described_class.new(note).execute }

      shared_examples_for 'not enqueueing MergeRequests::DuoCodeReviewChatWorker' do
        it 'does not enqueue MergeRequests::DuoCodeReviewChatWorker' do
          expect(::MergeRequests::DuoCodeReviewChatWorker).not_to receive(:perform_async)

          execute
        end
      end

      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(true)
        allow(note).to receive(:duo_bot_mentioned?).and_return(true)
      end

      it 'enqueues MergeRequests::DuoCodeReviewChatWorker' do
        expect(::MergeRequests::DuoCodeReviewChatWorker).to receive(:perform_async).with(note.id)

        execute
      end

      context 'when note is authored by GitLab Duo' do
        before do
          allow(note).to receive(:authored_by_duo_bot?).and_return(true)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end

      context 'when MergeRequest#ai_review_merge_request_allowed? returns false' do
        before do
          allow(merge_request).to receive(:ai_review_merge_request_allowed?).and_return(false)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end

      context 'when Note#duo_bot_mentioned? returns false' do
        before do
          allow(note).to receive(:duo_bot_mentioned?).and_return(false)
        end

        it_behaves_like 'not enqueueing MergeRequests::DuoCodeReviewChatWorker'
      end
    end

    context 'for processing AI flow triggers' do
      let_it_be(:user) { create(:user) }
      let_it_be(:mentioned_user) { create(:service_account) }
      let_it_be(:project) { create(:project, :in_group, developers: [user, mentioned_user]) }
      let_it_be(:issue) { create(:issue, project: project) }
      let_it_be(:note) { create(:note, project: project, noteable: issue, author: user) }

      let_it_be_with_reload(:flow_trigger) do
        create(:ai_flow_trigger, project: project, user: mentioned_user)
      end

      subject(:execute) { described_class.new(note).execute }

      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        stub_ee_application_setting(duo_features_enabled: true)
        allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)

        allow(note).to receive_messages({
          mentioned_users: [mentioned_user],
          note: "Test note content"
        })
      end

      shared_examples_for 'runs AI flow trigger service' do
        it 'calls Ai::FlowTriggers::RunService' do
          expect(::Ai::FlowTriggers::RunService).to receive(:new).and_call_original
          execute
        end
      end

      context 'for lazy-loading foundational mention triggers' do
        let_it_be(:group) { create(:group) }
        let_it_be(:project_with_foundational_flow) { create(:project, group: group) }
        let_it_be(:developer_user) { create(:user, developer_of: project_with_foundational_flow) }
        let_it_be(:service_account) { create(:service_account, provisioned_by_group: group) }
        let_it_be(:foundational_item) do
          create(:ai_catalog_item, :flow, :public,
            foundational_flow_reference: 'developer/v1',
            organization: group.organization)
        end

        let_it_be(:parent_consumer) do
          create(:ai_catalog_item_consumer,
            group: group,
            item: foundational_item,
            service_account: service_account,
            enabled: true,
            locked: true)
        end

        let_it_be(:child_consumer) do
          create(:ai_catalog_item_consumer,
            project: project_with_foundational_flow,
            item: foundational_item,
            parent_item_consumer: parent_consumer,
            enabled: true,
            locked: true)
        end

        let_it_be(:issue_for_foundational) { create(:issue, project: project_with_foundational_flow) }
        let_it_be(:note_for_foundational) do
          create(:note, project: project_with_foundational_flow, noteable: issue_for_foundational,
            author: developer_user)
        end

        subject(:execute_foundational) { described_class.new(note_for_foundational).execute }

        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?)
            .with(project_with_foundational_flow, :duo_workflow).and_return(true)
          stub_ee_application_setting(duo_features_enabled: true)
          allow(developer_user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)

          allow(note_for_foundational).to receive_messages({
            mentioned_users: [service_account],
            note: "Test note content"
          })
        end

        context 'when the mention trigger is missing for a foundational flow service account' do
          it 'creates the missing mention trigger before running flow triggers' do
            expect { execute_foundational }
              .to change { Ai::FlowTrigger.triggered_on(:mention).by_service_accounts([service_account]).count }
              .by(1)
          end

          it 'routes the lazily created trigger through the messaging adapter' do
            adapter = instance_double(::Ai::Messaging::Adapters::GitlabDuoNote)
            allow(::Ai::Messaging::Adapters::GitlabDuoNote).to receive(:for_note).and_return(adapter)
            allow(adapter).to receive(:with_lifecycle_hooks)

            execute_foundational

            expect(::Ai::Messaging::Adapters::GitlabDuoNote).to have_received(:for_note).with(
              note_for_foundational,
              note_author_id: service_account.id
            )
          end
        end

        context 'when trigger creation fails due to a validation error' do
          before do
            invalid_trigger = instance_double('Ai::FlowTrigger',
              persisted?: false,
              errors: instance_double(ActiveModel::Errors, full_messages: ['user must be a service account']))
            allow(Ai::FlowTrigger).to receive(:create).and_return(invalid_trigger)
          end

          it 'logs a warning and does not raise' do
            expect(::Gitlab::AppLogger).to receive(:warn).with(
              hash_including(
                message: "Failed to lazy-create foundational mention trigger",
                project_id: project_with_foundational_flow.id,
                user_id: service_account.id
              )
            )

            expect { execute_foundational }.not_to raise_error
          end
        end

        context 'when the mention trigger already exists for the service account' do
          before do
            create(:ai_flow_trigger,
              :for_catalog_consumer,
              project: project_with_foundational_flow,
              ai_catalog_item_consumer: child_consumer,
              event_types: [Ai::FlowTrigger::EVENT_TYPES[:mention]],
              description: 'Existing trigger')
          end

          it 'does not create a duplicate trigger' do
            expect { execute_foundational }
              .not_to change { Ai::FlowTrigger.triggered_on(:mention).by_service_accounts([service_account]).count }
          end
        end

        context 'for adapter routing' do
          let(:adapter) { instance_double(::Ai::Messaging::Adapters::GitlabDuoNote) }
          let(:run_service_instance) { instance_double(::Ai::FlowTriggers::RunService) }

          before do
            create(:ai_flow_trigger,
              :for_catalog_consumer,
              project: project_with_foundational_flow,
              ai_catalog_item_consumer: child_consumer,
              event_types: [Ai::FlowTrigger::EVENT_TYPES[:mention]],
              description: 'Existing trigger')
            allow(::Ai::Messaging::Adapters::GitlabDuoNote).to receive(:for_note).and_return(adapter)
            allow(adapter).to receive(:with_lifecycle_hooks).and_yield({ adapter: 'gitlab_duo_note' })
            allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service_instance)
            allow(run_service_instance).to receive(:execute)
          end

          it 'routes foundational mentions through the messaging adapter' do
            expect(::Ai::Messaging::Adapters::GitlabDuoNote).to receive(:for_note).with(
              note_for_foundational,
              note_author_id: service_account.id
            ).and_return(adapter)
            expect(adapter).to receive(:with_lifecycle_hooks)

            execute_foundational
          end

          it 'calls RunService with messaging_callback_context inside the lifecycle hooks block' do
            execute_foundational

            expect(run_service_instance).to have_received(:execute).with(
              hash_including(messaging_callback_context: { adapter: 'gitlab_duo_note' })
            )
          end
        end

        context 'when the mentioned user is not a service account' do
          let_it_be(:regular_user) { create(:user) }

          before do
            allow(note_for_foundational).to receive(:mentioned_users).and_return([regular_user])
          end

          it 'does not attempt to create any triggers' do
            expect(Ai::FlowTrigger).not_to receive(:create)

            execute_foundational
          end
        end

        context 'when the service account is not linked to a foundational flow' do
          let_it_be(:unlinked_service_account) { create(:service_account) }

          before do
            allow(note_for_foundational).to receive(:mentioned_users).and_return([unlinked_service_account])
          end

          it 'does not create a trigger' do
            expect { execute_foundational }
              .not_to change { Ai::FlowTrigger.count }
          end
        end

        context 'when the foundational flow does not declare a mention trigger' do
          before do
            allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).and_return(
              instance_double('Ai::Catalog::FoundationalFlow', triggers: [])
            )
          end

          it 'does not create a trigger' do
            expect { execute_foundational }
              .not_to change { Ai::FlowTrigger.count }
          end
        end

        context 'when the project has no child consumer for the foundational flow' do
          let_it_be(:project_without_consumer) { create(:project, group: group) }
          let_it_be(:issue_without_consumer) { create(:issue, project: project_without_consumer) }
          let_it_be(:note_without_consumer) do
            create(:note, project: project_without_consumer,
              noteable: issue_without_consumer, author: developer_user)
          end

          before_all do
            project_without_consumer.add_developer(developer_user)
          end

          before do
            allow(::Gitlab::Llm::StageCheck).to receive(:available?)
              .with(project_without_consumer, :duo_workflow).and_return(true)
            allow(note_without_consumer).to receive_messages(
              mentioned_users: [service_account],
              note: 'Test note content'
            )
          end

          it 'does not create a trigger and does not raise' do
            expect { described_class.new(note_without_consumer).execute }
              .not_to change { Ai::FlowTrigger.count }
          end
        end
      end

      shared_examples_for 'not running AI flow trigger service' do
        it 'does not call Ai::FlowTriggers::RunService' do
          expect(::Ai::FlowTriggers::RunService).not_to receive(:new)
          execute
        end
      end

      context 'when author can trigger AI flow' do
        context 'when there is a matching flow trigger' do
          it 'calls Ai::FlowTriggers::RunService with correct parameters' do
            service_instance = instance_double('Ai::FlowTriggers::RunService')

            expect(::Ai::FlowTriggers::RunService).to receive(:new).with(
              project: project,
              current_user: user,
              resource: issue,
              flow_trigger: flow_trigger
            ).and_return(service_instance)

            expect(service_instance).to receive(:execute).with(
              hash_including(
                event: :mention,
                discussion: note.discussion,
                discussion_id: note.discussion_id,
                note_id: note.id,
                triggered_by_username: user.username,
                input: a_string_including('<message'),
                source_context: a_string_including("Note: ")
              )
            )

            execute
          end

          context 'when multiple users are mentioned but only one has a trigger' do
            let(:other_mentioned_user) { create(:user) }

            before do
              allow(note).to receive(:mentioned_users).and_return([mentioned_user, other_mentioned_user])
            end

            it 'still triggers the service for the matching user' do
              service_instance = instance_double('Ai::FlowTriggers::RunService')

              expect(::Ai::FlowTriggers::RunService).to receive(:new).and_return(service_instance)
              expect(service_instance).to receive(:execute)

              execute
            end
          end

          context 'when multiple flow triggers exist but only one matches' do
            let_it_be(:other_flow_trigger) do
              create(:ai_flow_trigger, project: project)
            end

            it 'uses the first matching flow trigger' do
              service_instance = instance_double('Ai::FlowTriggers::RunService')

              expect(::Ai::FlowTriggers::RunService).to receive(:new).with(
                hash_including(flow_trigger: flow_trigger)
              ).and_return(service_instance)

              expect(service_instance).to receive(:execute)

              execute
            end
          end

          context 'when multiple flow triggers match the same mentioned user' do
            let_it_be(:second_flow_trigger) do
              create(:ai_flow_trigger, project: project, user: mentioned_user)
            end

            it 'triggers all matching flow triggers' do
              service_instance_1 = instance_double('Ai::FlowTriggers::RunService')
              service_instance_2 = instance_double('Ai::FlowTriggers::RunService')

              expect(::Ai::FlowTriggers::RunService).to receive(:new).with(
                hash_including(flow_trigger: flow_trigger)
              ).and_return(service_instance_1)

              expect(::Ai::FlowTriggers::RunService).to receive(:new).with(
                hash_including(flow_trigger: second_flow_trigger)
              ).and_return(service_instance_2)

              expect(service_instance_1).to receive(:execute).with(
                hash_including(
                  event: :mention,
                  discussion: note.discussion,
                  note_id: note.id,
                  triggered_by_username: user.username
                )
              )

              expect(service_instance_2).to receive(:execute).with(
                hash_including(
                  event: :mention,
                  discussion: note.discussion,
                  note_id: note.id,
                  triggered_by_username: user.username
                )
              )

              execute
            end
          end
        end

        context 'when there is no matching flow trigger' do
          before do
            allow(note).to receive(:mentioned_users).and_return([create(:user)])
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when no users are mentioned' do
          before do
            allow(note).to receive(:mentioned_users).and_return([])
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when the service account mentioned itself' do
          before do
            allow(note).to receive_messages(
              mentioned_users: [mentioned_user],
              author: mentioned_user
            )

            allow(mentioned_user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when the flow trigger is an item_consumer trigger' do
          let_it_be_with_reload(:flow_trigger) do
            create(:ai_flow_trigger, :for_catalog_consumer, project: project)
          end

          it_behaves_like 'runs AI flow trigger service'

          context 'when service account mentioned itself' do
            let_it_be(:mentioned_user) { flow_trigger.service_account }

            before_all do
              project.add_developer(mentioned_user)
            end

            before do
              allow(note).to receive_messages(
                mentioned_users: [mentioned_user],
                author: mentioned_user
              )

              allow(mentioned_user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(true)
            end

            it_behaves_like 'not running AI flow trigger service'
          end
        end

        context 'when flow trigger exists but for different trigger type' do
          before do
            stub_const("::Ai::FlowTrigger::EVENT_TYPES", {
              mention: 0,
              comment: 1,
              issue_created: 2
            })

            flow_trigger.update!(event_types: [1, 2])
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when project has no ai_flow_triggers association' do
          before do
            flow_trigger.destroy!
          end

          it_behaves_like 'not running AI flow trigger service'
        end
      end

      context 'when author cannot trigger AI flow' do
        before do
          allow(user).to receive(:allowed_to_use?).with(:duo_agent_platform, anything).and_return(false)
        end

        it_behaves_like 'not running AI flow trigger service'
      end

      context 'when note is on a non-project noteable (e.g., group-level epic)' do
        let_it_be(:group) { create(:group, developers: user) }
        let_it_be_with_reload(:epic) { create(:epic, group: group) }
        let_it_be(:namespaced_author) { create(:user, :with_namespace, developer_of: group) }
        let_it_be(:namespaced_sa) { create(:service_account, :with_namespace) }
        let_it_be_with_reload(:group_note) do
          create(:note_on_epic, noteable: epic, author: namespaced_author,
            note: "hey #{namespaced_sa.to_reference}")
        end

        subject(:execute) { described_class.new(group_note).execute }

        before do
          stub_licensed_features(epics: true)
          # The parent execute method calls EventCreateService which requires
          # project-level sharding keys not present on group-level noteables.
          allow_next_instance_of(EventCreateService) do |service|
            allow(service).to receive(:leave_note)
          end
        end

        it 'resolves the service account through real mention parsing (no stub)' do
          expect(group_note.project).to be_nil
          expect(group_note.mentioned_users).to include(namespaced_sa)
        end

        it_behaves_like 'not running AI flow trigger service'

        it 'posts a threaded reply authored by the mentioned service account', :aggregate_failures do
          expect { execute }.to change { Note.count }.by(1)

          new_notes = Note.where(noteable: epic).where('id > ?', group_note.id).order(:id)
          expect(new_notes.size).to eq(1)

          error_note = new_notes.first
          expect(error_note.author).to eq(namespaced_sa)
          expect(error_note.note).to include('not supported on group-level resources')
          expect(error_note.discussion_id).to eq(group_note.discussion_id)
        end

        context 'when the error note fails to persist' do
          before do
            unpersisted_note = Note.new
            unpersisted_note.errors.add(:base, 'some validation error')
            allow_next_instance_of(::Notes::CreateService) do |service|
              allow(service).to receive(:execute).and_return(unpersisted_note)
            end
          end

          it 'logs a warning with context' do
            expect(::Gitlab::AppLogger).to receive(:warn).with(
              hash_including(
                message: "Failed to post non-project noteable error reply",
                noteable_type: group_note.noteable_type,
                noteable_id: group_note.noteable_id,
                service_account_id: namespaced_sa.id,
                error: 'some validation error'
              )
            )

            execute
          end
        end

        context 'when no service accounts are mentioned' do
          let_it_be(:namespaced_human) { create(:user, :with_namespace, developer_of: group) }
          let_it_be_with_reload(:group_note) do
            create(:note_on_epic, noteable: create(:epic, group: group), author: namespaced_author,
              note: "hey #{namespaced_human.to_reference}")
          end

          it 'does not post an error reply' do
            expect { execute }.not_to change { Note.count }
          end

          it_behaves_like 'not running AI flow trigger service'
        end

        context 'when note has no noteable' do
          before do
            group_note.update_column(:noteable_id, nil)
          end

          it 'does not post an error reply' do
            expect { execute }.not_to change { Note.count }
          end
        end
      end
    end
  end
end
