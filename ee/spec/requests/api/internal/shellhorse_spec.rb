# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Shellhorse, feature_category: :source_code_management do
  include GitlabShellHelpers
  include APIInternalBaseHelpers
  include NamespaceStorageHelpers

  describe "POST /internal/shellhorse/git_audit_event", :clean_gitlab_redis_shared_state do
    let_it_be_with_reload(:user) { create(:user) }
    let_it_be(:group) { create(:group, :public) }
    let_it_be_with_reload(:project) { create(:project, :repository, :wiki_repo, namespace: group) }
    let(:allowed_ip) { '150.168.0.1' }
    let(:gl_repository) { "project-#{project.id}" }
    let(:key) { create(:key, user: user) }

    include_context 'workhorse headers'

    before do
      create(:audit_events_group_external_streaming_destination, group: group)
      create(:ip_restriction, group: group, range: allowed_ip)

      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    subject { post api('/internal/shellhorse/git_audit_event'), params: valid_params, headers: header }

    shared_context 'with git audit event env' do |shell_or_horse, protocol|
      let(:header) { shell_or_horse == 'shell' ? gitlab_shell_internal_api_request_header : workhorse_headers }
      let(:protocol) { protocol }
      let(:valid_params) do
        {
          protocol: protocol,
          action: action,
          username: key.user.username,
          gl_repository: gl_repository,
          packfile_stats: packfile_stats,
          check_ip: allowed_ip,
          changes: '_any',
          written_bytes: 1048576,
          received_bytes: 2048
        }
      end

      let(:expected_msg) do
        {
          protocol: protocol, action: action, verb: verb,
          written_bytes: 1048576, received_bytes: 2048,
          gl_key_type: 'key', gl_key_id: key.id
        }
      end
    end

    shared_examples 'logs single streaming audit event' do |protocol|
      using RSpec::Parameterized::TableSyntax

      let(:audit_message) do
        {
          name: 'repository_git_operation',
          stream_only: true,
          author: user,
          scope: project,
          target: project,
          message: expected_msg
        }
      end

      where(:action, :verb, :packfile_stats) do
        'git-receive-pack' | 'push'     | {}
        'git-upload-pack'  | 'clone'    | { wants: 2 }           #=> { wants: 2, haves: 0 }
        'git-upload-pack'  | 'pull'     | { wants: 2, haves: 2 } #=> { wants: 2, haves: 2 }
        'git-upload-pack'  | 'pull'     | { haves: 2 }           #=> { wants: 0, haves: 2 }
        'git-upload-pack'  | 'pull'     | {}                     #=> { wants: 0, haves: 0 }
      end

      with_them do
        it "logs git #{params[:verb]} streaming audit event for #{params[:action]}" do
          audit_message[:message][:ip_address] = allowed_ip if protocol == 'ssh'

          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(audit_message)).once

          subject

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["status"]).to be_truthy
          expect(json_response["message"]).to eq(expected_msg.stringify_keys)
        end

        context 'when log_git_streaming_audit_events is disabled' do
          before do
            stub_feature_flags(log_git_streaming_audit_events: false)
          end

          it "does not log git #{params[:verb]} streaming audit event for #{params[:action]}" do
            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["message"]).to eq('No git audit event needed')
          end
        end
      end
    end

    shared_examples 'logs streaming audit events' do |shell_or_horse, protocol|
      include_context 'with git audit event env', shell_or_horse, protocol

      before do
        project.add_developer(user)
        valid_params[:key_id] = key.id
      end

      context "when #{protocol} protocol from #{shell_or_horse} request" do
        it_behaves_like 'logs single streaming audit event', protocol: protocol
      end
    end

    shared_examples 'break response in several invalid cases' do |shell_or_horse, protocol|
      include_context 'with git audit event env', shell_or_horse, protocol

      let(:action) { 'git-upload-pack' }
      let(:packfile_stats) { { wants: 0, haves: 0 } }
      let(:verb) { 'clone' }

      context "when #{protocol} protocol from #{shell_or_horse} request" do
        context "with invalid action" do
          let(:action) { 'git_invalid_action' }

          it 'response with not found' do
            subject

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['success']).to be_falsey
            expect(json_response['message']).to eq('No valid action specified')
          end
        end

        context "when user does not exist" do
          before do
            valid_params.merge!({ username: 'none_user' })
          end

          it 'response with no audit event needed' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['status']).to be_falsey
            expect(json_response['message']).to eq('No git audit event needed')
          end
        end

        context "when project does not exist" do
          before do
            valid_params.merge!({ gl_repository: "project-#{non_existing_record_id}" })
          end

          it 'response with no audit event needed' do
            subject

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['status']).to be_falsey
            expect(json_response['message']).to eq('No git audit event needed')
          end
        end

        context 'when request times out' do
          it 'responds with a timeout' do
            expect_next_instance_of(Gitlab::GitAccess) do |access|
              expect(access).to receive(:check).and_raise(Gitlab::GitAccess::TimeoutError, "Timeout")
            end
            subject

            expect(response).to have_gitlab_http_status(:service_unavailable)
            expect(json_response['status']).to be_falsey
            expect(json_response['message']).to eq("Timeout")
          end
        end

        context "when access denied" do
          before do
            project.add_guest(user)
          end

          context "when git upload pack" do
            it 'response with none access' do
              subject

              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response["status"]).to be_falsey
            end
          end

          context "when git receive pack" do
            let(:action) { 'git-receive-pack' }
            let(:verb) { 'push' }

            it 'responsed with none access' do
              subject

              expect(response).to have_gitlab_http_status(:unauthorized)
              expect(json_response["status"]).to be_falsey
            end
          end
        end

        context 'when result is not ::Gitlab::GitAccessResult::Success' do
          it 'responds with 500' do
            allow_next_instance_of(Gitlab::GitAccess) do |access|
              allow(access).to receive(:check).and_return(nil)
            end

            allow_next_instance_of(::Gitlab::GitAuditEvent) do |audit|
              allow(audit).to receive(:enabled?).and_return(true)
            end

            subject

            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(json_response['status']).to be_falsey
            expect(json_response['message']).to eq(::API::Helpers::InternalHelpers::UNKNOWN_CHECK_RESULT_ERROR)
          end
        end
      end
    end

    { shell: 'Gitlab Shell', horse: 'Gitlab Workhorse' }.each do |key, val|
      context "when #{val} requests" do
        %w[ssh http].freeze.each do |protocol|
          context "with #{protocol} protocol" do
            it_behaves_like 'logs streaming audit events', key, protocol
            it_behaves_like 'break response in several invalid cases', key, protocol
          end
        end
      end
    end

    # Covers requests that originate from gitlab-shell over SSH and do not send
    # data transfer size params. The Ruby code handles this using `.present?`,
    # so `written_bytes` and `received_bytes` must be absent from both the
    # audit message and the JSON response in that case.
    context 'when data transfer size params are absent' do
      let(:header) { gitlab_shell_internal_api_request_header }
      let(:action) { 'git-upload-pack' }
      let(:valid_params) do
        {
          protocol: 'ssh',
          action: action,
          username: key.user.username,
          gl_repository: gl_repository,
          packfile_stats: { wants: 2 },
          check_ip: allowed_ip,
          changes: '_any'
        }
      end

      before do
        project.add_developer(user)
      end

      it 'does not include written_bytes or received_bytes in the audit message or response' do
        expected_audit = a_hash_including(
          name: 'repository_git_operation',
          stream_only: true,
          author: user,
          scope: project,
          target: project,
          message: hash_excluding(:written_bytes, :received_bytes)
        )

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_audit).once

        post api('/internal/shellhorse/git_audit_event'), params: valid_params, headers: header

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response["status"]).to be_truthy
        expect(json_response["message"]).not_to have_key('written_bytes')
        expect(json_response["message"]).not_to have_key('received_bytes')
      end
    end

    shared_examples 'does not generate a git audit event' do
      it 'does not generate a git audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        post api('/internal/shellhorse/git_audit_event'), params: valid_params, headers: header

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['status']).to be_falsey
        expect(json_response['message']).to eq('No git audit event needed')
      end
    end

    shared_examples 'logs git streaming audit event' do
      it 'logs git streaming audit event' do
        expected_audit = a_hash_including(
          name: 'repository_git_operation',
          stream_only: true,
          author: expected_author,
          scope: project,
          target: project
        )

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_audit).once

        subject

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['status']).to be_truthy
      end
    end

    # Deploy Key actor
    context 'when Gitlab Shell requests with ssh protocol for deploy keys' do
      let(:header) { gitlab_shell_internal_api_request_header }
      let(:base_params) do
        {
          action: 'git-upload-pack',
          gl_repository: gl_repository,
          packfile_stats: {},
          check_ip: allowed_ip,
          changes: '_any'
        }
      end

      context 'when actor is a deploy key with ghost user' do
        let(:deploy_key) { create(:deploy_key) }
        let(:expected_author) { deploy_key }
        let(:valid_params) { base_params.merge(protocol: 'ssh', key_id: deploy_key.id) }

        before do
          create(:deploy_keys_project, project: project, deploy_key: deploy_key)
        end

        it_behaves_like 'logs git streaming audit event'
      end

      context 'when actor is a deploy key with human user' do
        let(:deploy_key) { create(:deploy_key, user: user) }
        let(:expected_author) { deploy_key }
        let(:valid_params) { base_params.merge(protocol: 'ssh', key_id: deploy_key.id, packfile_stats: { wants: 2 }) }

        before do
          project.add_developer(user)
          create(:deploy_keys_project, project: project, deploy_key: deploy_key)
        end

        it_behaves_like 'logs git streaming audit event'

        context 'when log_git_streaming_audit_events is disabled' do
          before do
            stub_feature_flags(log_git_streaming_audit_events: false)
          end

          it_behaves_like 'does not generate a git audit event'
        end
      end
    end

    # Deploy Token actor
    context 'when Gitlab Workhorse requests with http protocol for deploy tokens' do
      let(:header) { workhorse_headers }
      let(:deploy_token) { create(:deploy_token, :project, projects: [project]) }
      let(:valid_params) do
        {
          protocol: 'http',
          action: 'git-upload-pack',
          gl_repository: gl_repository,
          identifier: "deploy-token-#{deploy_token.id}",
          username: "unrelated-user",
          packfile_stats: {},
          changes: '_any'
        }
      end

      context 'when actor is a deploy token' do
        let(:expected_author) { deploy_token }

        it_behaves_like 'logs git streaming audit event'
      end

      context 'when deploy token does not have project access' do
        let_it_be(:other_project) { create(:project, :repository) }
        let(:deploy_token) { create(:deploy_token, :project, projects: [other_project]) }

        it 'returns access denied' do
          post api('/internal/shellhorse/git_audit_event'), params: valid_params, headers: header

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['status']).to be_falsey
        end
      end

      context 'when log_git_streaming_audit_events is disabled' do
        before do
          stub_feature_flags(log_git_streaming_audit_events: false)
        end

        it_behaves_like 'does not generate a git audit event'
      end
    end
  end
end
