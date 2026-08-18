# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::AmazonQTriggerService, feature_category: :ai_agents do
  let_it_be(:organization) { create(:common_organization) }
  let_it_be_with_reload(:service_account) { create(:user, :service_account, composite_identity_enforced: true) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:merge_request) { create(:merge_request_with_diffs, source_project: project) }
  let_it_be(:oauth_app) { create(:doorkeeper_application) }
  let(:response) { instance_double(HTTParty::Response, success?: true, parsed_response: nil) }
  let(:source) { issue }
  let(:role_arn) { 'role-arn' }

  before do
    stub_current_organization(organization)
    ::Ai::Setting.for_organization(organization).update!(
      amazon_q_service_account_user_id: service_account.id,
      amazon_q_oauth_application_id: oauth_app.id,
      amazon_q_role_arn: role_arn
    )
  end

  describe '#execute' do
    let(:command) { 'dev' }
    let(:source) { 'issue' }
    let!(:note) { create(:note_on_issue, noteable: issue, project: project) }
    let(:service) { described_class.new(user: user, command: command, source: source, note: note) }
    let(:unit_primitive) { :amazon_q_integration }
    let(:expected_payload) { anything }
    let(:client) { instance_double(Gitlab::Llm::QAi::Client, create_event: response) }

    subject(:execution) { service.execute }

    before do
      allow(Gitlab::Llm::QAi::Client).to receive(:new).with(user).and_return(client)
      allow(SystemNoteService).to receive(:amazon_q_called).and_call_original
    end

    context 'with dev command' do
      let(:command) { 'dev' }

      shared_examples 'successful dev execution' do
        it 'creates an auth grant with the correct scopes', :aggregate_failures do
          expect(client).to receive(:create_event).with(payload: a_hash_including(command: command),
            role_arn: role_arn, event_id: "Quick Action")

          execution
        end

        it 'executes successfully' do
          expect { execution }.to change { Note.system.count }.by(1).and not_change { Note.user.count }
          expect(execution.parsed_response).to be_nil
          expect(SystemNoteService).to have_received(:amazon_q_called).with(source, user, command)
        end
      end

      context 'with a quick action in the issue description' do
        let(:source) { create(:issue, project: project, title: 'test issue', description: '/q dev') }
        let(:note) { nil }

        it_behaves_like 'successful dev execution'
      end

      context 'with issue' do
        let(:source) { issue }

        it_behaves_like 'successful dev execution'

        context 'when server returns a 500 error without an error message' do
          let(:response) { instance_double(HTTParty::Response, success?: false, parsed_response: nil) }

          before do
            allow(Gitlab::Llm::QAi::Client).to receive(:new).with(user).and_return(client)
          end

          it 'updates a new note with an error' do
            expect { execution }.to change { Note.system.count }.by(1).and change { Note.user.count }.by(1)
            expect(Note.last.note).to include(
              "Sorry, I'm not able to complete the request at this moment. Please try again later")
            expect(Note.last.note).to include("Request ID:")
          end
        end

        context 'when server returns a 500 error with an error message' do
          let_it_be(:error_message) do
            "An error occurred (AccessDeniedException) when calling the SendEvent operation: Identity Expired"
          end

          let(:response) do
            instance_double(
              HTTParty::Response, success?: false,
              parsed_response: error_message
            )
          end

          before do
            allow(Gitlab::Llm::QAi::Client).to receive(:new).with(user).and_return(client)
          end

          it 'updates a new note with an error detail' do
            expect { execution }.to change { Note.system.count }.by(1).and change { Note.user.count }.by(1)
            request_id = Labkit::Correlation::CorrelationId.current_id
            message = s_("AmazonQ|Sorry, I'm not able to complete the request at this moment. Please try again later.")
            request_id_message = format(s_("AmazonQ|Request ID: %{request_id}"), request_id: request_id)
            formatted_error_message = format(_('Error: %{error_message}'), error_message: error_message)

            expect(Note.last.note).to eq(<<~ERROR.chomp)
              > [!warning]
              >
              > #{message}
              >
              > #{request_id_message}
              >
              > #{formatted_error_message}
            ERROR
          end
        end
      end

      context 'with merge request' do
        let(:source) { merge_request }

        it_behaves_like 'successful dev execution'
      end
    end

    context 'with deprecated test command' do
      # `freeze: false` is required in this spec: one or more `let_it_be` subjects
      # cannot be frozen by default (deep_freeze traversal failure, a non-AR
      # subject, or an in-memory mutation that survives reload/refind). Do not
      # drop these opt-outs or convert them to `let_it_be_with_reload`/`refind`
      # (see gitlab-org/gitlab#602925).
      let_it_be(:diff_note, freeze: false) do
        build(:diff_note_on_merge_request, noteable: merge_request, project: project)
      end

      let(:command) { 'test' }
      let(:service) do
        described_class.new(user: user, command: command, source: source, note: diff_note,
          discussion_id: diff_note.discussion_id)
      end

      let(:source) { merge_request }

      it 'adds deprecation error to note' do
        service.execute

        expect(diff_note.errors[:quick_action]).to include(
          'command /q: /q test is now supported by using /q dev in an issue or merge request. ' \
            'To generate unit tests for this MR, add an inline comment and enter /q ' \
            'dev along with a comment about the tests you want written.'
        )
      end
    end

    context 'when handle error' do
      let(:command) { 'unsupported' }
      let(:source) { issue }
      let!(:service) do
        described_class.new(user: user, command: command, source: source, note: note,
          discussion_id: note.discussion_id)
      end

      before do
        allow(service).to receive(:handle_note_error)
        allow(Gitlab::AppLogger).to receive(:error)
      end

      context 'when UnsupportedCommandError is raised' do
        let(:error_message) { "Unsupported issue command: #{command}" }
        let(:error) do
          Ai::AmazonQValidateCommandSourceService::UnsupportedCommandError.new("Unsupported issue command: #{command}")
        end

        before do
          allow(service).to receive(:validate_source!).and_raise(error)
        end

        it 'logs the error and handles the note error' do
          expect(Gitlab::ErrorTracking).to receive(:log_exception).and_call_original
          expect(service).to receive(:handle_note_error).with(error_message)

          expect { execution }.not_to raise_error
        end
      end
    end

    describe '#payload' do
      let(:note) { create(:note_on_issue, noteable: issue, project: project) }
      let(:service) { described_class.new(user: user, command: 'dev', source: issue, note: note) }

      it 'generates the correct payload for an issue' do
        service.execute

        payload = service.send(:payload)

        expect(payload.keys).to match_array(
          %i[command source project_path project_id issue_id issue_iid discussion_id note_id role_arn])

        expect(payload[:command]).to eq('dev')
        expect(payload[:source]).to eq('issue')
        expect(payload[:project_path]).to eq(project.full_path)
        expect(payload[:project_id]).to eq(project.id.to_s)
        expect(payload[:issue_id]).to eq(issue.id.to_s)
        expect(payload[:issue_iid]).to eq(issue.iid.to_s)
      end

      context 'when the source is a work item' do
        let(:noteable) { create(:work_item, :issue, project: project) }
        let(:note) { create(:note_on_issue, noteable: noteable, project: project) }

        it 'generates the correct payload for an issue' do
          service.execute

          payload = service.send(:payload)

          expect(payload.keys).to match_array(
            %i[command source project_path project_id issue_id issue_iid discussion_id note_id role_arn])

          expect(payload[:command]).to eq('dev')
          expect(payload[:source]).to eq('issue')
          expect(payload[:project_path]).to eq(project.full_path)
          expect(payload[:project_id]).to eq(project.id.to_s)
          expect(payload[:issue_id]).to eq(issue.id.to_s)
          expect(payload[:issue_iid]).to eq(issue.iid.to_s)
        end
      end
    end
  end

  describe '#amazon_q_service_account' do
    let(:service) { described_class.new(user: user, command: 'dev', source: issue) }

    context 'when service account exists' do
      before do
        Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: service_account.id)
      end

      it 'returns service account user object' do
        service_account_user = service.send(:amazon_q_service_account)

        expect(service_account_user).to eq(service_account)
      end
    end
  end

  describe '#validate_service_account!' do
    let(:service) { described_class.new(user: user, command: 'dev', source: issue) }

    context 'when service account is properly configured' do
      before do
        Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: service_account.id)
      end

      it 'returns true' do
        expect(service.send(:validate_service_account!)).to be true
      end
    end

    context 'when service account does not exist' do
      before do
        Ai::Setting.for_organization(organization).update!(amazon_q_service_account_user_id: nil)
      end

      it 'raises ServiceAccountError' do
        expect { service.send(:validate_service_account!) }
          .to raise_error(
            Ai::AmazonQ::AmazonQTriggerService::ServiceAccountError,
            'dev failed due to Amazon Q service account ID is not configured'
          )
      end
    end

    context 'when service account does not have composite identity enabled' do
      before do
        service_account.update!(composite_identity_enforced: false)
      end

      it 'raises CompositeIdentityEnforcedError' do
        expect { service.send(:validate_service_account!) }.to raise_error(
          Ai::AmazonQ::AmazonQTriggerService::CompositeIdentityEnforcedError,
          "Cannot find the service account with composite identity enabled"
        )
      end
    end
  end

  describe '#search_comments_by_service_account' do
    let(:discussion) do
      create(:discussion_note_on_issue, noteable: issue, project: issue.project, note: "test note",
        author: service_account).discussion
    end

    let(:service) do
      described_class.new(user: user, command: 'dev', source: issue, note: discussion.notes.first,
        discussion_id: discussion.notes.first.discussion_id)
    end

    it 'filters notes by author_id' do
      expect(service.send(:search_comments_by_service_account).count).to eq(1)
    end

    context 'when keyword is blank' do
      it 'returns notes filtered by author_id' do
        expect(service.send(:search_comments_by_service_account, []).count).to eq(1)
      end
    end

    context 'when keyword is present' do
      it 'filters notes by keyword' do
        expect(service.send(:search_comments_by_service_account, ['test']).count).to eq(1)
      end

      it 'returns empty array when not found keyword' do
        expect(service.send(:search_comments_by_service_account, ['unknown'])).to be_empty
      end
    end
  end

  describe '#handle_note_error' do
    let!(:note) { create(:note_on_issue, noteable: issue, project: project) }
    let(:error_message) { "Test error message" }

    context 'when note is already defined' do
      let(:service) { described_class.new(user: user, command: 'dev', source: issue, note: note) }

      before do
        allow(service).to receive(:note).and_return(note)
      end

      it 'adds error to the existing note' do
        error = service.send(:handle_note_error, error_message)
        expect(error.type).to eq("command /q: #{error_message}")
      end
    end
  end

  describe '#create_note' do
    let(:original_note) { create(:note_on_issue, noteable: issue, project: project) }
    let(:command) { 'dev' }
    let(:generated_message) do
      "I'm generating code for this issue. I'll update this comment and open a merge request when I'm done."
    end

    let(:service) { described_class.new(user: user, command: command, source: source, note: original_note) }
    let(:update_service) { instance_double(Notes::UpdateService) }

    before do
      allow(service).to receive_messages(
        amazon_q_service_account: service_account
      )
    end

    context 'when note exists' do
      before do
        allow(Notes::UpdateService).to receive(:new)
          .with(project, service_account, { note: generated_message, author: service_account })
          .and_return(update_service)
        allow(update_service).to receive(:execute).and_return(original_note)
      end

      it 'creates a new note with correct parameters' do
        service.send(:create_note)

        expect(Notes::UpdateService).to have_received(:new)
          .with(project, service_account, { note: generated_message, author: service_account })
        expect(update_service).to have_received(:execute).with(kind_of(Note))
      end

      it 'sets the progress note' do
        service.send(:create_note)

        expect(service.instance_variable_get(:@progress_note)).to eq(original_note)
      end
    end

    context 'when note does not exist' do
      before do
        allow(service).to receive(:note).and_return(nil)
      end

      it 'returns nil without creating a note' do
        expect(Notes::UpdateService).not_to receive(:new)

        expect(service.send(:create_note)).to be_nil
      end
    end
  end

  describe '#update_failure_note' do
    let_it_be(:note) { create(:note_on_issue, noteable: issue, project: project) }

    let(:service) { described_class.new(user: user, command: 'dev', source: issue, note: note) }
    let(:failure_message) { 'Error occurred' }

    before do
      allow(service).to receive(:failure_message).and_return(failure_message)
    end

    context 'when progress note does not exist' do
      let(:create_service) { instance_double(Notes::CreateService) }
      let(:created_note) { create(:note) }

      before do
        service.instance_variable_set(:@progress_note, nil)

        allow(Notes::CreateService).to receive(:new)
          .with(
            issue.project,
            service_account,
            {
              author: service_account,
              noteable: issue,
              note: failure_message,
              discussion_id: note.discussion_id
            }
          ).and_return(create_service)
        allow(create_service).to receive(:execute).and_return(created_note)
      end

      it 'creates a new note with failure message' do
        service.send(:update_failure_note)

        expect(Notes::CreateService).to have_received(:new)
          .with(
            issue.project,
            service_account,
            {
              author: service_account,
              noteable: issue,
              note: failure_message,
              discussion_id: note.discussion_id
            }
          )
        expect(create_service).to have_received(:execute)
      end

      it 'sets the progress note to the newly created note' do
        service.send(:update_failure_note)

        expect(service.instance_variable_get(:@progress_note)).to eq(created_note)
      end
    end

    context 'when note is nil' do
      let(:service) { described_class.new(user: user, command: 'dev', source: issue, note: nil) }
      let(:create_service) { instance_double(Notes::CreateService) }
      let(:created_note) { create(:note) }

      before do
        service.instance_variable_set(:@progress_note, nil)

        allow(Notes::CreateService).to receive(:new)
          .with(
            issue.project,
            service_account,
            {
              author: service_account,
              noteable: issue,
              note: failure_message,
              discussion_id: nil
            }
          ).and_return(create_service)
        allow(create_service).to receive(:execute).and_return(created_note)
      end

      it 'creates a new note without discussion_id' do
        service.send(:update_failure_note)

        expect(Notes::CreateService).to have_received(:new)
          .with(
            issue.project,
            service_account,
            {
              author: service_account,
              noteable: issue,
              note: failure_message,
              discussion_id: nil
            }
          )
        expect(create_service).to have_received(:execute)
      end
    end
  end

  describe '#failure_message' do
    let(:service) { described_class.new(user: user, command: 'dev', source: issue) }
    let(:request_id) { 'test-request-id-123' }

    before do
      allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return(request_id)
    end

    context 'when error is ResourceNotFoundException' do
      let(:error_string) do
        'An error occurred (ResourceNotFoundException) when calling the SendEvent operation: Resource not found.'
      end

      it 'returns user-friendly reconnection message' do
        result = service.send(:failure_message, error_string)

        expect(result).to include('Your Amazon Q connection is missing or has been deleted')
        expect(result).to include("Request ID: #{request_id}")
      end
    end

    context 'when error is not ResourceNotFoundException' do
      let(:error_string) { 'Some other error occurred' }

      it 'returns generic error message' do
        result = service.send(:failure_message, error_string)

        expect(result).to include("Sorry, I'm not able to complete the request at this moment")
        expect(result).to include("Request ID: #{request_id}")
      end
    end
  end

  describe '#resource_not_found_error?' do
    let(:service) { described_class.new(user: user, command: 'dev', source: issue) }

    it 'returns true for ResourceNotFoundException with SendEvent operation' do
      error_string = 'An error occurred (ResourceNotFoundException) when calling ' \
        'the SendEvent operation: Resource not found.'
      expect(service.send(:resource_not_found_error?, error_string)).to be true
    end

    it 'returns false for other errors' do
      error_string = 'An error occurred (AccessDeniedException) when calling the SendEvent operation: Access denied.'
      expect(service.send(:resource_not_found_error?, error_string)).to be false
    end

    it 'returns false for nil or blank strings' do
      expect(service.send(:resource_not_found_error?, nil)).to be false
      expect(service.send(:resource_not_found_error?, '')).to be false
    end
  end
end
