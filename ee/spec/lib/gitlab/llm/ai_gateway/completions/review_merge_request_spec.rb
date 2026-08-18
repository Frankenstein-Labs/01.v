# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::ReviewMergeRequest, feature_category: :duo_code_review do
  let(:review_prompt_class) { Gitlab::Llm::Templates::ReviewMergeRequest }
  let(:summarize_review_class) { Gitlab::Llm::AiGateway::Completions::SummarizeReview }
  let(:tracking_context) { { request_id: 'uuid', action: :review_merge_request } }
  let(:options) { { progress_note_id: progress_note.id } }
  let(:create_note_allowed?) { true }
  let(:prompt_version) { '1.3.0' }
  let(:received_model_metadata) { { provider: 'gitlab', feature_setting: 'review_merge_request', identifier: nil } }

  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:project) do
    create(:project, :custom_repo, files: { 'UPDATED.md' => "existing line 1\nexisting line 2\n" })
  end

  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be(:source_branch) { 'review-merge-request-test' }
  let_it_be(:merge_request) do
    project.repository.create_branch(source_branch, project.default_branch)
    project.repository.update_file(
      user,
      'UPDATED.md',
      "existing line 1\nnew line 1\nnew line 2",
      message: 'Update file',
      branch_name: source_branch)

    project.repository.create_file(
      user,
      'NEW.md',
      "new line1\n  new line 2\n",
      message: 'Create file',
      branch_name: source_branch)

    create(
      :merge_request,
      target_project: project,
      source_project: project,
      source_branch: source_branch,
      target_branch: project.default_branch
    )
  end

  let_it_be(:diff_refs) { merge_request.diff_refs }
  let_it_be(:progress_note) do
    create(
      :note,
      note: 'progress note',
      project: project,
      noteable: merge_request,
      author: Users::Internal.in_organization(project.organization_id).duo_code_review_bot,
      system: true
    )
  end

  let(:review_prompt_message) do
    build(:ai_message, :review_merge_request, user: user, resource: merge_request, request_id: 'uuid')
  end

  let(:help_page_link) do
    ::Gitlab::Utils.append_path(Gitlab::Routing.url_helpers.root_url,
      Gitlab::Routing.url_helpers.help_page_path('user/gitlab_duo/context.md',
        anchor: 'exclude-context-from-gitlab-duo'))
  end

  subject(:completion) { described_class.new(review_prompt_message, review_prompt_class, options) }

  describe '#ai_gateway_timeout' do
    it 'returns 120 seconds' do
      expect(completion.send(:ai_gateway_timeout)).to eq(120.seconds)
    end
  end

  describe '#root_namespace' do
    context 'when the target project is in a subgroup' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, :small_repo, group: subgroup) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      it 'returns the root namespace' do
        expect(completion.root_namespace).to eq(group)
      end
    end

    context 'when the target project is in a group at the root level' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, :small_repo, group: group) }
      let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

      it 'returns the root namespace' do
        expect(completion.root_namespace).to eq(group)
      end
    end

    context 'when the target project is in a user namespace' do
      it 'returns the root namespace' do
        expect(completion.root_namespace).to eq(project.root_namespace)
      end
    end
  end

  describe '#execute' do
    let(:combined_review_prompt) { { messages: ['This is the combined review prompt'] } }
    let(:summary_answer) { 'This is a summary response' }
    let(:summary_response_modifier) do
      { ai_message: instance_double(Gitlab::Llm::AiMessage, content: summary_answer, errors: []) }
    end

    let(:prompt_inputs) do
      {
        mr_title: 'MR Title',
        mr_description: 'MR Description',
        diff_lines: 'Diff lines',
        full_file_intro: 'Full file intro',
        full_content_section: 'Full content section',
        custom_instructions_section: 'Custom instructions section'
      }
    end

    let(:diffs_and_paths) do
      {
        'UPDATED.md' => anything,
        'NEW.md' => anything
      }
    end

    before do
      allow_next_instance_of(Gitlab::Duo::CodeReview::CustomInstructionsResolver) do |resolver|
        allow(resolver).to receive(:execute).and_return([])
      end

      allow_next_instance_of(
        review_prompt_class,
        mr_title: merge_request.title,
        mr_description: merge_request.description,
        diffs_and_paths: kind_of(Hash),
        files_content: kind_of(Hash),
        custom_instructions: kind_of(Array),
        user: user
      ) do |template|
        allow(template).to receive(:to_prompt_inputs).and_return(prompt_inputs)
      end

      allow_next_instance_of(Gitlab::Llm::AiGateway::Client, user,
        unit_primitive_name: :review_merge_request,
        tracking_context: tracking_context,
        namespace_id: nil,
        project_id: nil,
        governing_namespace_id: merge_request.target_project.root_ancestor.id
      ) do |client|
        allow(client)
          .to receive(:complete_prompt)
          .with(
            base_url: Gitlab::AiGateway.url,
            prompt_name: :review_merge_request,
            inputs: prompt_inputs,
            model_metadata: received_model_metadata,
            prompt_version: prompt_version,
            timeout: 120.seconds
          )
          .and_return(
            instance_double(HTTParty::Response, body: combined_review_response.to_json, success?: true)
          )
      end

      allow_next_instance_of(summarize_review_class) do |completions|
        allow(completions).to receive(:execute).and_return(summary_response_modifier)
      end
    end

    after do
      RSpec::Mocks.space.reset_all
    end

    shared_examples_for 'review merge request with prompt version' do
      it 'sends AIGW request with correct model metadata' do
        expect_next_instance_of(Gitlab::Llm::AiGateway::Client, user,
          unit_primitive_name: :review_merge_request,
          tracking_context: tracking_context,
          namespace_id: nil,
          project_id: nil,
          governing_namespace_id: merge_request.target_project.root_ancestor.id
        ) do |client|
          allow(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :review_merge_request,
              inputs: prompt_inputs,
              model_metadata: received_model_metadata,
              prompt_version: prompt_version,
              timeout: 120.seconds
            )
            .and_return(
              instance_double(HTTParty::Response, body: combined_review_response.to_json, success?: true)
            )
        end

        completion.execute
      end
    end

    context 'when passing file contents to ai_prompt_class' do
      let(:combined_review_response) { '<review></review>' }
      let(:updated_file_content) { "existing line 1\nexisting line 2\n" }
      let(:updated_blob) { instance_double(Blob, data: updated_file_content) }
      let(:diff_files) do
        [
          instance_double(Gitlab::Diff::File,
            new_path: 'UPDATED.md',
            file_path: 'UPDATED.md',
            new_file?: false,
            deleted_file?: false,
            old_path: 'UPDATED.md',
            old_blob: updated_blob,
            raw_diff: '@@ -1,2 +1,2 @@ existing line'),
          instance_double(Gitlab::Diff::File,
            new_path: 'NEW.md',
            file_path: 'NEW.md',
            new_file?: true,
            deleted_file?: false,
            old_path: 'NEW.md',
            raw_diff: '@@ -0,0 +1,2 @@ new line'),
          instance_double(Gitlab::Diff::File,
            new_path: 'DELETED.md',
            file_path: 'DELETED.md',
            new_file?: false,
            deleted_file?: true,
            old_path: 'DELETED.md',
            raw_diff: '@@ -1,2 +0,0 @@ old line')
        ]
      end

      before do
        # Setup reviewable files
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return(diff_files)

        allow_next_instance_of(Gitlab::Llm::Anthropic::Client, user,
          unit_primitive: 'review_merge_request',
          tracking_context: tracking_context
        ) do |client|
          allow(client).to receive(:messages_complete).and_return(combined_review_response)
        end

        allow_next_instance_of(Gitlab::Llm::AiGateway::Client, user,
          unit_primitive_name: :review_merge_request,
          tracking_context: tracking_context,
          namespace_id: nil,
          project_id: nil,
          governing_namespace_id: merge_request.target_project.root_ancestor.id
        ) do |client|
          allow(client)
            .to receive(:complete_prompt)
            .with(
              base_url: Gitlab::AiGateway.url,
              prompt_name: :review_merge_request,
              inputs: prompt_inputs,
              model_metadata: received_model_metadata,
              prompt_version: prompt_version,
              timeout: 120.seconds
            )
            .and_return(
              instance_double(HTTParty::Response, body: combined_review_response.to_json, success?: true)
            )
        end
      end

      it 'only includes original content of modified files (not new or deleted files)' do
        expect(review_prompt_class).to receive(:new).with(
          hash_including(
            mr_title: merge_request.title,
            mr_description: merge_request.description,
            files_content: { 'UPDATED.md' => updated_file_content }
          )
        ) do |args|
          expect(args[:files_content].keys).not_to include('NEW.md')

          instance_double(
            review_prompt_class,
            to_prompt_inputs: prompt_inputs
          )
        end

        completion.execute
      end
    end

    context 'when merge request has no reviewable files' do
      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([])
      end

      it 'creates a note with nothing to review message' do
        expect(completion).to receive(:update_progress_note).with(Gitlab::Duo::CodeReview::Messages.nothing_to_review)

        completion.execute
      end
    end

    context 'when the chat client returns a successful response' do
      let(:combined_review_response) do
        <<~RESPONSE
          <review>
          <comment file="UPDATED.md" old_line="" new_line="2">
          First comment with suggestions
          With additional line
          <from>
          new line 1
          new line 2
          </from>
          <to>
              first improved line
                second improved line
          </to>
          Some more comments
          </comment>
          <comment file="NEW.md" old_line="" new_line="1">Second comment</comment>
          <comment file="NEW.md" old_line="" new_line="2">Third comment</comment>
          <comment file="NEW.md" old_line="" new_line="2">Fourth comment</comment>
          </review>
        RESPONSE
      end

      let(:summary_answer) { 'Helpful review summary' }

      it 'creates diff notes on new and updated files' do
        completion.execute

        diff_notes = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).reorder(:id)
        expect(diff_notes.count).to eq 4

        first_note = diff_notes[0]
        expect(first_note.note).to eq 'Second comment'
        expect(first_note.position.to_h).to eq({
          base_sha: diff_refs.base_sha,
          start_sha: diff_refs.start_sha,
          head_sha: diff_refs.head_sha,
          old_path: 'NEW.md',
          new_path: 'NEW.md',
          position_type: 'text',
          old_line: nil,
          new_line: 1,
          line_range: nil,
          ignore_whitespace_change: false
        })

        second_note = diff_notes[1]
        expect(second_note.note).to eq 'Third comment'
        expect(second_note.position.to_h).to eq({
          base_sha: diff_refs.base_sha,
          start_sha: diff_refs.start_sha,
          head_sha: diff_refs.head_sha,
          old_path: 'NEW.md',
          new_path: 'NEW.md',
          position_type: 'text',
          old_line: nil,
          new_line: 2,
          line_range: nil,
          ignore_whitespace_change: false
        })

        third_note = diff_notes[2]
        expect(third_note.note).to eq 'Fourth comment'

        fourth_note = diff_notes[3]
        expect(fourth_note.note).to eq <<~NOTE_CONTENT
          First comment with suggestions
          With additional line
          ```suggestion:-0+1
              first improved line
                second improved line
          ```
          Some more comments
        NOTE_CONTENT

        expect(fourth_note.position.to_h).to eq({
          base_sha: diff_refs.base_sha,
          start_sha: diff_refs.start_sha,
          head_sha: diff_refs.head_sha,
          old_path: 'UPDATED.md',
          new_path: 'UPDATED.md',
          position_type: 'text',
          old_line: nil,
          new_line: 2,
          line_range: nil,
          ignore_whitespace_change: false
        })
      end

      it 'destroys progress note' do
        completion.execute

        expect(Note.exists?(progress_note.id)).to be_falsey
      end

      it 'performs review and creates a note' do
        expect do
          completion.execute
        end.to change { merge_request.notes.diff_notes.count }.by(4)
          .and not_change { merge_request.notes.non_diff_notes.count }

        expect(merge_request.notes.non_diff_notes.last.note).to eq(summary_answer)
      end

      context 'when draft_notes is empty after mapping DraftNote objects' do
        let(:combined_review_response) do
          <<~RESPONSE
            <review>
            </review>
          RESPONSE
        end

        it 'updates progress note with no comment message and creates a todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute

          expect(merge_request.notes.diff_notes.count).to eq 0
          expect(merge_request.notes.non_diff_notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.nothing_to_comment)
        end
      end

      context 'when draft_notes is empty after mapping DraftNote objects and no comments provided' do
        let(:combined_review_response) do
          <<~RESPONSE
          <review>
          </review>
          RESPONSE
        end

        it 'updates progress note with no comment message and creates a todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute

          expected_message = <<~RESPONSE.chomp
          #{Gitlab::Duo::CodeReview::Messages.nothing_to_comment}
          RESPONSE
          expect(merge_request.notes.non_diff_notes.last.note).to eq(expected_message)
        end
      end

      context 'when review note already exists on the same position' do
        let(:progress_note2) do
          create(
            :note,
            note: 'progress note 2',
            project: project,
            noteable: merge_request,
            author: Users::Internal.in_organization(project.organization_id).duo_code_review_bot,
            system: true
          )
        end

        before do
          described_class.new(review_prompt_message, review_prompt_class, progress_note_id: progress_note2.id).execute
        end

        it 'does not add more notes to the same position' do
          expect { completion.execute }
            .to not_change { merge_request.notes.diff_notes.count }
            .and not_change { merge_request.notes.non_diff_notes.count }

          expect(merge_request.notes.non_diff_notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.nothing_to_comment)
        end
      end

      context 'when resource is empty' do
        let(:review_prompt_message) do
          build(:ai_message, :review_merge_request, user: user, resource: nil, request_id: 'uuid')
        end

        it 'creates a note and return' do
          expect do
            described_class.new(review_prompt_message, review_prompt_class, options).execute
          end.to not_change { merge_request.notes.diff_notes.count }
            .and not_change { merge_request.notes.non_diff_notes.count }

          expect(merge_request.notes.non_diff_notes.last.note).to eq(
            Gitlab::Duo::CodeReview::Messages.merge_request_not_found_error
          )
        end
      end

      context 'when progress note is not provided' do
        let(:options) { {} }

        it 'creates progress note and finish review as expected' do
          expect do
            completion.execute
          end.to change { merge_request.notes.diff_notes.count }.by(4)
            .and change { merge_request.notes.non_diff_notes.count }.by(1)

          expect(merge_request.notes.non_diff_notes.last.note).to eq(summary_answer)
        end

        context 'when resource is empty' do
          let(:review_prompt_message) do
            build(:ai_message, :review_merge_request, user: user, resource: nil, request_id: 'uuid')
          end

          it 'does not execute review and raise exception' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              StandardError.new("Unable to perform Duo Code Review: progress_note and resource not found"),
              unit_primitive: 'review_merge_request'
            )

            expect do
              described_class.new(review_prompt_message, review_prompt_class, options).execute
            end.to not_change { merge_request.notes.diff_notes.count }
              .and not_change { merge_request.notes.non_diff_notes.count }
          end
        end
      end

      context 'when the chat client response includes invalid comments' do
        let(:combined_review_response) do
          <<~RESPONSE
            <review>
            <comment file="UPDATED.md">First comment with no line numbers</comment>
            <comment file="UPDATED.md" old_line="" new_line="2">Second comment</comment>
            <comment file="NEW.md" old_line="" new_line="">Fourth comment with missing lines</comment>
            <comment file="NEW.md" old_line="" new_line="10">Fifth comment with invalid line</comment>
            </review>
          RESPONSE
        end

        it 'creates a valid comment only' do
          completion.execute

          diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

          expect(diff_note.note).to eq 'Second comment'
          expect(diff_note.position.new_line).to eq(2)
        end

        context 'when the exact line could not be found' do
          let(:combined_review_response) do
            <<~RESPONSE
            <review>
            <comment file="UPDATED.md" old_line="2" new_line="2">Second comment</comment>
            </review>
            RESPONSE
          end

          it 'matches it using new_line only' do
            completion.execute

            diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

            expect(diff_note.note).to eq 'Second comment'
            expect(diff_note.position.new_line).to eq(2)
          end
        end

        context 'with <from> content' do
          context 'with no matching line by line numbers' do
            let(:combined_review_response) do
              <<~RESPONSE
                <review>
                <comment file="UPDATED.md" old_line="" new_line="10">A comment with a suggestion
                <from>
                existing line 1
                new line 1
                new line 2
                </from>
                <to>
                existing line 1
                first improved line
                second improved line
                </to>
                </comment>
                </review>
              RESPONSE
            end

            it 'uses the line matched by <from> content' do
              completion.execute

              diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

              expect(diff_note.note).to eq <<~NOTE_CONTENT
                  A comment with a suggestion
                  ```suggestion:-0+2
                  existing line 1
                  first improved line
                  second improved line
                  ```
              NOTE_CONTENT
              expect(diff_note.position.old_line).to eq(1)
              expect(diff_note.position.new_line).to eq(1)
            end

            it 'logs matched comment metrics' do
              # Ignore other logs
              allow(Gitlab::AppLogger).to receive(:info)

              expect(Gitlab::AppLogger).to receive(:info).with(
                hash_including(
                  event: "review_merge_request_llm_response_comments",
                  comments_line_matched_by_content: 1
                )
              )

              completion.execute
            end

            context 'when <from> content only partially matches' do
              let(:combined_review_response) do
                <<~RESPONSE
                  <review>
                  <comment file="UPDATED.md" old_line="" new_line="10">A comment with a suggestion
                  <from>
                  existing line 1
                  new line 1
                  some random content
                  </from>
                  <to>
                  existing line 1
                  first improved line
                  second improved line
                  </to>
                  </comment>
                  </review>
                RESPONSE
              end

              it 'does not create a diff note' do
                completion.execute

                diff_notes = merge_request.notes.diff_notes.authored_by(duo_code_review_bot)

                expect(diff_notes).to be_blank
              end
            end
          end

          context 'with matching line by line numbers' do
            context 'when the matched line do not match <from> content' do
              let(:combined_review_response) do
                <<~RESPONSE
                  <review>
                  <comment file="UPDATED.md" old_line="" new_line="2">A comment with a suggestion
                  <from>
                  existing line 1
                  new line 1
                  new line 2
                  </from>
                  <to>
                  existing line 1
                  first improved line
                  second improved line
                  </to>
                  </comment>
                  </review>
                RESPONSE
              end

              it 'uses the line matched by <from> content' do
                completion.execute

                diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

                expect(diff_note.note).to eq <<~NOTE_CONTENT
                  A comment with a suggestion
                  ```suggestion:-0+2
                  existing line 1
                  first improved line
                  second improved line
                  ```
                NOTE_CONTENT
                expect(diff_note.position.old_line).to eq(1)
                expect(diff_note.position.new_line).to eq(1)
              end

              it 'logs matched comment metrics' do
                # Ignore other logs
                allow(Gitlab::AppLogger).to receive(:info)

                expect(Gitlab::AppLogger).to receive(:info).with(
                  hash_including(
                    event: "review_merge_request_llm_response_comments",
                    comments_line_matched_by_content: 1
                  )
                )

                completion.execute
              end

              context 'when <from> content is not long enough' do
                let(:combined_review_response) do
                  <<~RESPONSE
                    <review>
                    <comment file="UPDATED.md" old_line="" new_line="2">A comment with a suggestion
                    <from>
                    existing line 1
                    new line 1
                    </from>
                    <to>
                    existing line 1
                    first improved line
                    second improved line
                    </to>
                    </comment>
                    </review>
                  RESPONSE
                end

                it 'still uses the line found by line number' do
                  completion.execute

                  diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

                  expect(diff_note.note).to eq <<~NOTE_CONTENT
                    A comment with a suggestion
                    ```suggestion:-0+1
                    existing line 1
                    first improved line
                    second improved line
                    ```
                  NOTE_CONTENT
                  expect(diff_note.position.old_line).to be_nil
                  expect(diff_note.position.new_line).to eq(2)
                end
              end

              context 'when <from> content cannot be matched' do
                let(:combined_review_response) do
                  <<~RESPONSE
                    <review>
                    <comment file="UPDATED.md" old_line="" new_line="2">A comment with a suggestion
                    <from>
                    some random content
                    that do not match
                    antything
                    </from>
                    <to>
                    existing line 1
                    first improved line
                    second improved line
                    </to>
                    </comment>
                    </review>
                  RESPONSE
                end

                it 'uses the line matched by line numbers' do
                  completion.execute

                  diff_note = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).sole

                  expect(diff_note.note).to eq <<~NOTE_CONTENT
                  A comment with a suggestion
                  ```suggestion:-0+2
                  existing line 1
                  first improved line
                  second improved line
                  ```
                  NOTE_CONTENT
                  expect(diff_note.position.old_line).to be_nil
                  expect(diff_note.position.new_line).to eq(2)
                end
              end
            end
          end
        end
      end

      context 'when the chat client decides to return contents outside of <review> tag' do
        let(:combined_review_response) do
          <<~RESPONSE
            Let me explain how awesome this review is.
            <review>
            <comment file="UPDATED.md" old_line="" new_line="2">First comment</comment>
            <comment file="NEW.md" old_line="" new_line="1">Second comment</comment>
            </review>
          RESPONSE
        end

        it 'creates valid <review> section only' do
          completion.execute

          diff_notes = merge_request.notes.diff_notes.authored_by(duo_code_review_bot).reorder(:id)
          expect(diff_notes.count).to eq 2

          first_note = diff_notes[0]
          expect(first_note.note).to eq 'Second comment'
          expect(first_note.position.new_line).to eq(1)

          second_note = diff_notes[1]
          expect(second_note.note).to eq 'First comment'
          expect(second_note.position.new_line).to eq(2)
        end
      end

      context 'when user is not allowed to create notes' do
        let(:user) { create(:user) }

        it 'does not publish review' do
          expect(DraftNote).not_to receive(:bulk_insert!)
          expect(DraftNotes::PublishService).not_to receive(:new)

          completion.execute
        end
      end

      context 'when there were no comments' do
        let(:combined_review_response) { {} }

        it 'creates a note with an error message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
        end

        it 'creates a new todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute
        end
      end

      context 'when review response is blank' do
        let(:combined_review_response) { '' }

        it 'creates a note with an error message' do
          completion.execute

          expect(merge_request.notes.count).to eq 1
          expect(merge_request.notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
        end

        it 'creates a new todo' do
          expect_any_instance_of(TodoService) do |service|
            expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
          end

          completion.execute
        end
      end

      context 'when there were some comments' do
        context 'when an error gets raised' do
          before do
            allow(DraftNote).to receive(:new).and_raise('error')
          end

          it 'creates a note with an error message' do
            completion.execute

            expect(merge_request.notes.non_diff_notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
          end
        end

        context 'when summary returned an error' do
          let(:summary_response_modifier) do
            {
              ai_message: instance_double(
                Gitlab::Llm::AiMessage,
                content: '',
                errors: ['Oh, no. Something went wrong!']
              )
            }
          end

          it 'creates a note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 5
            expect(merge_request.notes.diff_notes.count).to eq 4
            expect(merge_request.notes.non_diff_notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
          end
        end

        context 'when summary returned no result' do
          let(:summary_answer) { '' }

          it 'creates a note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 5
            expect(merge_request.notes.diff_notes.count).to eq 4
            expect(merge_request.notes.non_diff_notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
          end
        end

        context 'when summary response is blank' do
          let(:summary_response_modifier) do
            { ai_message: instance_double(Gitlab::Llm::AiMessage, content: '', errors: []) }
          end

          it 'creates a note with an error message' do
            completion.execute

            expect(merge_request.notes.count).to eq 5
            expect(merge_request.notes.diff_notes.count).to eq 4
            expect(merge_request.notes.non_diff_notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
          end
        end
      end

      context 'when draft notes limit is reached' do
        before do
          stub_const("#{described_class}::DRAFT_NOTES_COUNT_LIMIT", 1)
        end

        it 'creates diff note on the first file only' do
          completion.execute

          diff_notes = merge_request.notes.diff_notes
          expect(diff_notes.count).to eq 1

          expect(diff_notes[0].note).to eq 'Second comment'
          expect(diff_notes[0].position.to_h).to eq({
            base_sha: diff_refs.base_sha,
            start_sha: diff_refs.start_sha,
            head_sha: diff_refs.head_sha,
            old_path: 'NEW.md',
            new_path: 'NEW.md',
            position_type: 'text',
            old_line: nil,
            new_line: 1,
            line_range: nil,
            ignore_whitespace_change: false
          })
        end
      end

      it 'calls UpdateReviewerStateService with review states' do
        expect_next_instance_of(
          MergeRequests::UpdateReviewerStateService,
          project: project, current_user: ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot
        ) do |service|
          expect(service).to receive(:execute).with(merge_request, 'review_started')
          expect(service).to receive(:execute).with(merge_request, 'reviewed')
        end

        completion.execute
      end

      context 'when there is an error due of large prompt' do
        let(:retry_response) { { "content" => [{ "text" => "<review></review>" }] } }

        let(:example_error_response) do
          instance_double(HTTParty::Response, body: %(Some error).to_json, success?: false)
        end

        let(:example_retry_response) do
          instance_double(HTTParty::Response, body: retry_response.to_json, success?: true)
        end

        before do
          allow(Gitlab::AppLogger).to receive(:info)
        end

        it 'regenerates the prompt without file content' do
          # We expect that a new prompt is generated with `files_content` as empty hash when we retry.
          expect_next_instance_of(
            review_prompt_class,
            hash_including(
              files_content: {}
            )
          ) do |template|
            expect(template).to receive(:to_prompt_inputs).and_return(prompt_inputs)
          end

          allow_next_instance_of(
            Gitlab::Llm::AiGateway::Client,
            user,
            unit_primitive_name: :review_merge_request,
            tracking_context: tracking_context,
            namespace_id: nil,
            project_id: nil,
            governing_namespace_id: merge_request.target_project.root_ancestor.id
          ) do |client|
            expect(client)
              .to receive(:complete_prompt)
              .with(
                base_url: Gitlab::AiGateway.url,
                prompt_name: :review_merge_request,
                inputs: kind_of(Hash),
                model_metadata: received_model_metadata,
                prompt_version: prompt_version,
                timeout: 120.seconds
              )
              .and_return(example_error_response)

            # On retry, AiGateway client instantiated separately, instead of reusing the same instance.
            allow_next_instance_of(
              Gitlab::Llm::AiGateway::Client,
              user,
              unit_primitive_name: :review_merge_request,
              tracking_context: tracking_context,
              namespace_id: nil,
              project_id: nil,
              governing_namespace_id: merge_request.target_project.root_ancestor.id
            ) do |client2|
              expect(client2)
                .to receive(:complete_prompt)
                .with(
                  base_url: Gitlab::AiGateway.url,
                  prompt_name: :review_merge_request,
                  inputs: kind_of(Hash),
                  model_metadata: received_model_metadata,
                  prompt_version: prompt_version,
                  timeout: 120.seconds
                )
                .and_return(example_retry_response)
            end
          end

          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: "Review request failed with files content, retrying without file content",
              event: "review_merge_request_retry_without_content",
              unit_primitive: 'review_merge_request',
              merge_request_id: merge_request&.id,
              error: ["An unexpected error has occurred."]
            )
          )

          completion.execute
        end
      end
    end

    context 'when AI Gateway returns an error' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:request!).and_return({ 'detail' => 'Connection timeout' })
        end
      end

      it 'creates a note with error message' do
        completion.execute

        expect(merge_request.notes.count).to eq 1
        expect(merge_request.notes.last.note).to eq(Gitlab::Duo::CodeReview::Messages.generic_error)
      end

      it 'creates a new todo' do
        expect_any_instance_of(TodoService) do |service|
          expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
        end

        completion.execute
      end

      it 'logs error details when logging is enabled' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: "Review request failed with files content, retrying without file content",
            event: "review_merge_request_retry_without_content"
          )
        )

        expect(Gitlab::AppLogger).to receive(:info).with(
          message: "Review merge request encountered an invalid response",
          event: "review_merge_request_invalid_response",
          unit_primitive: 'review_merge_request',
          merge_request_id: merge_request.id,
          errors: ['Connection timeout']
        )

        completion.execute
      end
    end

    context 'when logging LLM response comments metrics' do
      let(:expected_hash) do
        {
          message: "LLM response comments metrics",
          event: "review_merge_request_llm_response_comments",
          unit_primitive: 'review_merge_request',
          merge_request_id: merge_request.id,
          total_comments: 0,
          comments_with_valid_path: 0,
          comments_with_valid_line: 0,
          comments_with_custom_instructions: 0,
          comments_line_matched_by_content: 0,
          created_draft_notes: 0
        }
      end

      before do
        # Ignore other logs
        allow(Gitlab::AppLogger).to receive(:info)
      end

      context 'with a successful response containing comments' do
        let(:combined_review_response) do
          <<~RESPONSE
            <review>
            <comment file="UPDATED.md" old_line="1" new_line="1">first comment</comment>
            <comment file="UPDATED.md" old_line="" new_line="2">second comment</comment>
            <comment file="NEW.md" old_line="" new_line="1">third comment</comment>
            <comment file="NEW.md" old_line="" new_line="3">comment with unknown line</comment>
            <comment file="SOMETHINGRANDOM" old_line="" new_line="3">comment with unknown filename</comment>
            </review>
          RESPONSE
        end

        it 'logs expected comment metrics' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              expected_hash.merge(
                total_comments: 5,
                comments_with_valid_path: 4,
                comments_with_valid_line: 3,
                comments_with_custom_instructions: 0,
                comments_line_matched_by_content: 0,
                created_draft_notes: 3
              )
            )
          )

          completion.execute
        end

        context 'when response contains comments from custom instructions' do
          let(:combined_review_response) do
            <<~RESPONSE
          <review>
          <comment file="UPDATED.md" old_line="1" new_line="1">According to custom instructions in Ruby Style Guide: first comment</comment>
          <comment file="UPDATED.md" old_line="" new_line="2">second comment</comment>
          <comment file="NEW.md" old_line="" new_line="1">According to custom instructions in Markdown Standards: third comment</comment>
          <comment file="NEW.md" old_line="" new_line="3">regular comment</comment>
          </review>
            RESPONSE
          end

          it 'logs expected comment metrics with custom instructions count' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              hash_including(
                expected_hash.merge(
                  total_comments: 4,
                  comments_with_valid_path: 4,
                  comments_with_valid_line: 3,
                  comments_with_custom_instructions: 2,
                  comments_line_matched_by_content: 0,
                  created_draft_notes: 3
                )
              )
            )

            completion.execute
          end
        end

        context 'when duo_code_review_response_logging feature flag is disabled' do
          before do
            stub_feature_flags(duo_code_review_response_logging: false)
          end

          it 'does not log comment metrics' do
            expect(Gitlab::AppLogger).not_to receive(:info).with(
              hash_including(
                message: "LLM response comments metrics",
                event: "review_merge_request_llm_response_comments"
              )
            )

            completion.execute
          end
        end
      end

      context 'with a successful response containing no comments' do
        let(:combined_review_response) { '<review></review>' }

        it 'log comment metrics' do
          expect(Gitlab::AppLogger).to receive(:info).with(hash_including(expected_hash))

          completion.execute
        end
      end
    end

    context 'when the AI response is <review></review>' do
      let(:combined_review_response) { ' <review></review> ' }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end

      it 'does not raise an error' do
        expect { completion.execute }.not_to raise_error
      end
    end

    context 'when the chat client returns an unsuccessful response' do
      let(:combined_review_response) { { detail: 'Error' } }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end
    end

    context 'when the AI response is empty' do
      let(:combined_review_response) { {} }

      it 'does not call DraftNote#new' do
        expect(DraftNote).not_to receive(:new)

        completion.execute
      end

      it 'does not raise an error' do
        expect { completion.execute }.not_to raise_error
      end
    end

    context 'when tracking Duo Code Review internal events' do
      let(:combined_review_response) do
        <<~RESPONSE
          <review>
          <comment file="UPDATED.md" old_line="" new_line="2">First comment</comment>
          </review>
        RESPONSE
      end

      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([instance_double(Gitlab::Diff::File,
          new_path: 'UPDATED.md',
          file_path: 'UPDATED.md',
          new_file?: false,
          old_path: 'UPDATED.md',
          old_blob: instance_double(Blob, data: 'content'),
          raw_diff: '@@ -1,2 +1,2 @@ existing line',
          diff_lines: [instance_double(Gitlab::Diff::Line, old_line: nil, new_line: 2)],
          deleted_file?: false
        )])
      end

      context 'when Duo Code Review posts a diff comment' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:trimmed_draft_note_params).and_return([
              { merge_request: merge_request, author: duo_code_review_bot, note: 'First diff comment' },
              { merge_request: merge_request, author: duo_code_review_bot, note: 'Second diff comment' }
            ])
          end
        end

        it 'tracks the diff comments event appropriately' do
          expect { completion.execute }
            .to trigger_internal_events('post_comment_duo_code_review_on_diff')
            .with(user: user, project: merge_request.project, additional_properties: { value: 2 })
            .and increment_usage_metrics('counts.count_total_post_comment_duo_code_review_on_diff').by(2)
        end
      end

      context 'when no issues are found after review' do
        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:trimmed_draft_note_params).and_return([])
          end
        end

        it 'tracks the no issues found event' do
          expect { completion.execute }
            .to trigger_internal_events('find_no_issues_duo_code_review_after_review')
            .with(user: user, project: merge_request.project)
            .exactly(1).times
        end
      end

      context 'when there are no reviewable diff files' do
        before do
          allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([])
        end

        it 'tracks nothing to review event' do
          expect { completion.execute }
            .to trigger_internal_events('find_nothing_to_review_duo_code_review_on_mr')
            .with(user: user, project: merge_request.project)
            .exactly(1).times
        end
      end

      context 'when an error occurs during review' do
        before do
          error = StandardError.new("Test error")
          allow_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
            allow(client).to receive(:complete_prompt).and_raise(error)
          end
        end

        it 'tracks the error event' do
          expect { completion.execute }
            .to trigger_internal_events('encounter_duo_code_review_error_during_review')
            .with(user: user, project: merge_request.project)
            .exactly(1).times
        end
      end
    end

    context "with custom instructions" do
      context 'when custom instructions file does not exist' do
        it 'passes empty custom instructions to the review prompt' do
          expect(review_prompt_class).to receive(:new).with(
            hash_including(
              custom_instructions: []
            )
          )

          completion.execute
        end
      end

      context 'with custom instructions' do
        let(:group_instruction) do
          instance_double(
            Gitlab::Duo::CodeReview::CustomInstruction,
            name: 'Group instruction',
            instructions: 'Review group-level rules'
          )
        end

        it 'delegates to CustomInstructionsResolver' do
          expect_next_instance_of(Gitlab::Duo::CodeReview::CustomInstructionsResolver) do |resolver|
            expect(resolver).to receive(:execute).with(merge_request).and_return([group_instruction])
          end

          expect(review_prompt_class).to receive(:new).with(
            hash_including(custom_instructions: [group_instruction])
          )

          completion.execute
        end

        context 'when the resolver returns empty instructions' do
          before do
            allow_next_instance_of(Gitlab::Duo::CodeReview::CustomInstructionsResolver) do |resolver|
              allow(resolver).to receive(:execute).and_return([])
            end
          end

          it 'passes empty custom instructions to the prompt' do
            expect(review_prompt_class).to receive(:new).with(
              hash_including(custom_instructions: [])
            )

            completion.execute
          end
        end
      end
    end

    context 'with model switching enabled', :saas_gitlab_com_subscriptions do
      it_behaves_like 'review merge request with prompt version'

      context 'when the model is pinned to a specific model' do
        let_it_be(:group) { create(:group) }
        let_it_be(:subgroup) { create(:group, parent: group) }
        let_it_be(:project) { create(:project, :small_repo, group: subgroup) }
        let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

        let(:received_model_metadata) do
          {
            feature_setting: 'review_merge_request',
            identifier: 'claude_sonnet_3_7',
            provider: 'gitlab'
          }
        end

        before do
          create(:ai_namespace_feature_setting,
            namespace: group,
            feature: 'review_merge_request'
          )
        end

        it_behaves_like 'review merge request with prompt version'
      end
    end

    context 'with excluded files functionality' do
      let(:combined_review_response) { '<review></review>' }

      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([])
      end

      context 'when FileExclusionService returns excluded files' do
        let(:excluded_files) { ['app/logs/application.log', 'secret_key.txt'] }
        let(:file_paths) { ['app/models/user.rb', 'app/logs/application.log', 'secret_key.txt'] }
        let(:exclusion_service_result) do
          ServiceResponse.success(payload: [
            { path: 'app/models/user.rb', excluded: false },
            { path: 'app/logs/application.log', excluded: true },
            { path: 'secret_key.txt', excluded: true }
          ])
        end

        before do
          # Mock the diff files to simulate files in the merge request
          diff_files = file_paths.map do |file_path|
            instance_double(Gitlab::Diff::File, file_path: file_path)
          end

          allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return(diff_files)

          # Mock the FileExclusionService
          exclusion_service = instance_double(::Ai::FileExclusionService)
          allow(::Ai::FileExclusionService).to receive(:new).with(merge_request.project).and_return(exclusion_service)
          allow(exclusion_service).to receive(:execute).with(file_paths).and_return(exclusion_service_result)
        end

        it 'includes exclusion message in the progress note' do
          expected_message = <<~MESSAGE.chomp
            I do not have access to the following files due to an active context exclusion policy:
            * app/logs/application.log
            * secret_key.txt
            [Learn more](#{help_page_link})

            #{Gitlab::Duo::CodeReview::Messages.nothing_to_review}
          MESSAGE

          expect(completion).to receive(:update_progress_note).with(expected_message)

          completion.execute
        end

        it 'tracks excluded files internal event' do
          expect { completion.execute }
            .to trigger_internal_events('excluded_files_from_duo_code_review')
            .with(user: user, project: merge_request.project)
            .exactly(1).times
        end

        context 'when there are reviewable files and excluded files' do
          before do
            diff_file = instance_double(Gitlab::Diff::File,
              new_path: 'app/models/user.rb',
              file_path: 'app/models/user.rb',
              new_file?: false,
              deleted_file?: false,
              old_path: 'app/models/user.rb',
              old_blob: instance_double(Blob, data: 'class User'),
              raw_diff: '@@ -1,2 +1,2 @@ class User',
              diff_lines: [instance_double(Gitlab::Diff::Line, old_line: nil, new_line: 1)]
            )

            allow(diff_file).to receive(:line_for_position).and_return(instance_double(Gitlab::Diff::Line,
              old_line: nil, new_line: 1))

            allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([diff_file])
          end

          it 'includes exclusion message in the summary note' do
            expected_exclusion_message = <<~MESSAGE.chomp
              I do not have access to the following files due to an active context exclusion policy:
              * app/logs/application.log
              * secret_key.txt
              [Learn more](#{help_page_link})
            MESSAGE

            expected_full_message = "#{expected_exclusion_message}\n\n#{Gitlab::Duo::CodeReview::Messages.nothing_to_comment}"

            expect(completion).to receive(:update_progress_note).with(expected_full_message, with_todo: true)

            completion.execute
          end
        end

        context 'when there are comments and excluded files' do
          let(:combined_review_response) do
            <<~RESPONSE
                      <review>
                      <comment file="app/models/user.rb" old_line="" new_line="1">Good code structure</comment>
                      </review>
            RESPONSE
          end

          let(:summary_answer) { 'Review completed successfully' }

          before do
            diff_file = instance_double(Gitlab::Diff::File,
              new_path: 'app/models/user.rb',
              file_path: 'app/models/user.rb',
              new_file?: false,
              deleted_file?: false,
              old_path: 'app/models/user.rb',
              old_blob: instance_double(Blob, data: 'class User'),
              raw_diff: '@@ -1,2 +1,2 @@ class User',
              diff_lines: [instance_double(Gitlab::Diff::Line, old_line: nil, new_line: 1)]
            )

            allow(diff_file).to receive(:line_for_position).and_return(instance_double(Gitlab::Diff::Line,
              old_line: nil, new_line: 1))
            allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([diff_file])
            allow(DraftNotes::PublishService).to receive_message_chain(:new, :execute)
          end

          it 'includes exclusion message in the summary note with AI response' do
            expected_exclusion_message = <<~MESSAGE.chomp
              I do not have access to the following files due to an active context exclusion policy:
              * app/logs/application.log
              * secret_key.txt
              [Learn more](#{help_page_link})
            MESSAGE

            expected_full_message = "#{expected_exclusion_message}\n\n#{summary_answer}"

            completion.execute

            expect(merge_request.notes.non_diff_notes.last.note).to eq(expected_full_message)
          end
        end

        context 'when FileExclusionService returns no excluded files' do
          let(:file_paths) { ['app/models/user.rb', 'app/controllers/users_controller.rb'] }
          let(:exclusion_service_result) do
            ServiceResponse.success(payload: [
              { path: 'app/models/user.rb', excluded: false },
              { path: 'app/controllers/users_controller.rb', excluded: false }
            ])
          end

          before do
            diff_files = file_paths.map do |file_path|
              instance_double(Gitlab::Diff::File, file_path: file_path)
            end

            allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return(diff_files)

            exclusion_service = instance_double(::Ai::FileExclusionService)
            allow(::Ai::FileExclusionService).to receive(:new).with(merge_request.project).and_return(exclusion_service)
            allow(exclusion_service).to receive(:execute).with(file_paths).and_return(exclusion_service_result)
          end

          it 'does not include exclusion message' do
            expect(completion).to receive(:update_progress_note).with(Gitlab::Duo::CodeReview::Messages.nothing_to_review)

            completion.execute
          end

          it 'does not track excluded files internal event' do
            expect { completion.execute }
              .not_to trigger_internal_events('excluded_files_from_duo_code_review')
          end
        end

        context 'when FileExclusionService returns an error' do
          let(:file_paths) { ['app/models/user.rb'] }
          let(:exclusion_service_result) do
            ServiceResponse.error(message: 'Service unavailable')
          end

          before do
            diff_files = file_paths.map do |file_path|
              instance_double(Gitlab::Diff::File, file_path: file_path)
            end

            allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return(diff_files)

            exclusion_service = instance_double(::Ai::FileExclusionService)
            allow(::Ai::FileExclusionService).to receive(:new).with(merge_request.project).and_return(exclusion_service)
            allow(exclusion_service).to receive(:execute).with(file_paths).and_return(exclusion_service_result)
          end

          it 'does not include exclusion message when service fails' do
            expect(completion).to receive(:update_progress_note).with(Gitlab::Duo::CodeReview::Messages.nothing_to_review)

            completion.execute
          end

          it 'does not track excluded files internal event' do
            expect { completion.execute }
              .not_to trigger_internal_events('excluded_files_from_duo_code_review')
          end
        end

        context 'when merge request has no diff files' do
          before do
            allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return([])
          end

          it 'does not call FileExclusionService' do
            expect(::Ai::FileExclusionService).not_to receive(:new)

            completion.execute
          end

          it 'does not include exclusion message' do
            expect(completion).to receive(:update_progress_note).with(Gitlab::Duo::CodeReview::Messages.nothing_to_review)

            completion.execute
          end
        end
      end
    end
  end
end
