# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SystemNotes::AgentsService, feature_category: :duo_agent_platform do
  let_it_be(:namespace) { create(:namespace, path: 'test-namespace') }
  let_it_be(:project) { create(:project, namespace: namespace, path: 'test-project') }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:agent_author) { create(:user) }
  let_it_be(:service_account_user) { create(:user, :service_account) }

  let(:noteable) { issue }
  let(:service) { described_class.new(noteable: noteable, container: project, author: author) }
  let(:session_id) { '123' }
  let(:expected_session_url) { "http://localhost/test-namespace/test-project/-/automate/agent-sessions/123" }

  before do
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:agent_author).with(service_account_user).and_return(agent_author)
    end
  end

  describe '#agent_session_started' do
    let(:trigger_source) { user }

    subject(:system_note) { service.agent_session_started(session_id, trigger_source, service_account_user) }

    it_behaves_like 'a system note' do
      let(:author) { agent_author }
      let(:action) { 'duo_agent_started' }
    end

    context 'when session is started by user' do
      it 'sets the note text with user trigger as a @username reference' do
        expected_note = "started session [#{session_id}](#{expected_session_url}) " \
          "triggered by #{trigger_source.to_reference}"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when trigger_source is nil' do
      let(:trigger_source) { nil }

      it 'sets the note text without trigger source' do
        expected_note = "started session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when trigger_source is empty string' do
      let(:trigger_source) { '' }

      it 'sets the note text without trigger source' do
        expected_note = "started session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe '#agent_session_completed' do
    subject(:system_note) { service.agent_session_completed(session_id, service_account_user) }

    it_behaves_like 'a system note' do
      let(:author) { agent_author }
      let(:action) { 'duo_agent_completed' }
    end

    context 'when session is completed successfully' do
      it 'sets the note text' do
        expected_note = "completed session [#{session_id}](#{expected_session_url})"

        expect(system_note.note).to eq(expected_note)
      end
    end
  end

  describe '#agent_session_failed' do
    let(:reason) { nil }

    subject(:system_note) { service.agent_session_failed(session_id, service_account_user, reason) }

    it_behaves_like 'a system note' do
      let(:author) { agent_author }
      let(:action) { 'duo_agent_failed' }
    end

    context 'when session fails without reason' do
      it 'sets the note text without reason' do
        expected_note = "session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when session fails with reason' do
      let(:reason) { 'dropped' }

      it 'sets the note text with reason' do
        expected_note = "session [#{session_id}](#{expected_session_url}) failed (dropped)"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when reason is empty string' do
      let(:reason) { '' }

      it 'sets the note text without reason' do
        expected_note = "session [#{session_id}](#{expected_session_url}) failed"

        expect(system_note.note).to eq(expected_note)
      end
    end

    context 'when no valid author is available' do
      before do
        allow(service).to receive(:agent_author).and_call_original
      end

      it 'returns nil and does not create a note' do
        expect(service.agent_session_failed(session_id, nil, 'dropped')).to be_nil
      end
    end
  end

  describe 'tracks different noteables' do
    context 'when noteable is a merge request' do
      let_it_be(:merge_request) { create(:merge_request, source_project: project) }
      let(:noteable) { merge_request }

      it 'creates system note for merge request' do
        note = service.agent_session_started(session_id, user, service_account_user)
        expect(note.noteable).to eq(merge_request)
        expect(note.project).to eq(project)
        expect(note.author).to eq(agent_author)
      end
    end

    context 'when noteable is an Issue' do
      it 'creates system note for Issue' do
        note = service.agent_session_started(session_id, user, service_account_user)
        expect(note.noteable).to eq(issue)
        expect(note.project).to eq(project)
        expect(note.author).to eq(agent_author)
      end
    end
  end

  describe '#agent_author' do
    subject(:result) { service.send(:agent_author, user) }

    before do
      allow(service).to receive(:agent_author).and_call_original
    end

    context 'when user is a service account user' do
      let(:user) { service_account_user }

      it 'returns the service_account_user' do
        expect(result).to eq(service_account_user)
      end
    end

    context 'when user is a regular user' do
      let(:user) { instance_double(User, service_account?: false) }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end

    context 'when user is nil' do
      let(:user) { nil }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end

  describe '#format_trigger_source' do
    subject(:formatted_trigger_source) { service.send(:format_trigger_source, trigger_source) }

    context 'when trigger_source is a User' do
      let(:trigger_source) { user }

      it 'returns a @username reference' do
        expect(formatted_trigger_source).to eq("@#{user.username}")
      end
    end

    context 'when trigger_source is a String' do
      let(:trigger_source) { 'Pipeline' }

      it 'returns the escaped string' do
        expect(formatted_trigger_source).to eq('Pipeline')
      end

      context 'when string contains HTML characters' do
        let(:trigger_source) { '<script>alert("xss")</script>' }

        it 'escapes HTML characters' do
          expect(formatted_trigger_source).to eq('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
          expect(formatted_trigger_source).not_to include('<script>')
        end
      end

      context 'when string contains special characters' do
        let(:trigger_source) { 'CI/CD Pipeline & Automation' }

        it 'escapes special characters' do
          escaped_result = ERB::Util.html_escape(trigger_source)
          expect(formatted_trigger_source).to eq(escaped_result)
          expect(formatted_trigger_source).to include('&amp;')
        end
      end
    end

    context 'when trigger_source is a Symbol' do
      let(:trigger_source) { :trigger_agent }

      it 'converts to string and escapes it' do
        expect(formatted_trigger_source).to eq('trigger_agent')
      end
    end

    context 'when trigger_source is an Integer' do
      let(:trigger_source) { 42 }

      it 'converts to string' do
        expect(formatted_trigger_source).to eq('42')
      end
    end

    context 'when trigger_source is nil' do
      let(:trigger_source) { nil }

      it 'returns empty string' do
        expect(formatted_trigger_source).to eq('')
      end
    end
  end
end
