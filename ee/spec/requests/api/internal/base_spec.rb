# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Base, feature_category: :source_code_management do
  include GitlabShellHelpers
  include EE::GeoHelpers
  include APIInternalBaseHelpers
  include NamespaceStorageHelpers
  include GitlabSubscriptions::SubscriptionHelpers

  let_it_be(:primary_url) { 'http://primary.example.com' }
  let_it_be(:secondary_url) { 'http://secondary.example.com' }
  let_it_be_with_reload(:primary_node) { create(:geo_node, :primary, url: primary_url) }
  let_it_be_with_reload(:secondary_node) { create(:geo_node, url: secondary_url) }
  let_it_be_with_reload(:user) { create(:user) }

  describe 'POST /internal/post_receive', :geo do
    let(:key) { create(:key, user: user) }
    let_it_be_with_reload(:project) { create(:project, :repository, :wiki_repo) }

    let(:gl_repository) { "project-#{project.id}" }
    let(:reference_counter) { double('ReferenceCounter') }

    let(:identifier) { 'key-123' }

    let(:valid_params) do
      {
        gl_repository: gl_repository,
        identifier: identifier,
        changes: changes,
        push_options: {}
      }
    end

    let(:branch_name) { 'feature' }

    let(:changes) do
      "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/#{branch_name}"
    end

    let(:git_push_http) { double('GitPushHttp') }

    before do
      project.add_developer(user)
      allow(described_class).to receive(:identify).and_return(user)
      allow_next_instance_of(Gitlab::Identifier) do |instance|
        allow(instance).to receive(:identify).and_return(user)
      end
      stub_current_geo_node(primary_node)
    end

    context 'when the push was redirected from a Geo secondary to the primary' do
      before do
        expect(Gitlab::Geo::GitPushHttp).to receive(:new).with(identifier, gl_repository).and_return(git_push_http)
        expect(git_push_http).to receive(:fetch_referrer_node).and_return(secondary_node)
      end

      it 'includes a message advising a redirection occurred' do
        redirect_message = <<~STR
        This request to a Geo secondary node will be forwarded to the
        Geo primary node:

          http://primary.example.com/#{project.full_path}.git
        STR

        post api('/internal/post_receive'), params: valid_params, headers: gitlab_shell_internal_api_request_header

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['messages']).to include({
          'type' => 'basic',
          'message' => redirect_message
        })
      end
    end
  end

  describe "POST /internal/allowed" do
    let_it_be(:key) { create(:key, user: user) }

    context "project alias" do
      let(:project) { create(:project, :public, :repository) }
      let(:project_alias) { create(:project_alias, project: project) }

      def check_access_by_alias(alias_name)
        post(
          api("/internal/allowed"),
          params: {
            action: "git-upload-pack",
            key_id: key.id,
            project: alias_name,
            protocol: 'ssh'
          },
          headers: gitlab_shell_internal_api_request_header
        )
      end

      context "without premium license" do
        context "project matches a project alias" do
          before do
            check_access_by_alias(project_alias.name)
          end

          it "does not allow access because project can't be found" do
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end

      context "with premium license" do
        before do
          stub_licensed_features(project_aliases: true)
        end

        context "project matches a project alias" do
          before do
            check_access_by_alias(project_alias.name)
          end

          it "allows access" do
            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context "project doesn't match a project alias" do
          before do
            check_access_by_alias('some-project')
          end

          it "does not allow access because project can't be found" do
            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end

    context 'smartcard session required' do
      let_it_be(:project, freeze: false) { create(:project, :repository, :wiki_repo) }

      subject do
        post(
          api("/internal/allowed"),
          params: { key_id: key.id,
                    project: project.full_path,
                    gl_repository: "project-#{project.id}",
                    action: 'git-upload-pack',
                    protocol: 'ssh' },
          headers: gitlab_shell_internal_api_request_header
        )
      end

      before do
        stub_licensed_features(smartcard_auth: true)
        stub_smartcard_setting(enabled: true, required_for_git_access: true)

        project.add_developer(user)
      end

      context 'user with a smartcard session', :clean_gitlab_redis_sessions do
        let(:session_id) { '42' }
        let(:stored_session) do
          { 'smartcard_signins' => { 'last_signin_at' => 5.minutes.ago } }
        end

        before do
          Gitlab::Redis::Sessions.with do |redis|
            redis.set("session:gitlab:#{session_id}", Marshal.dump(stored_session))
            redis.sadd("session:lookup:user:gitlab:#{user.id}", [session_id])
          end
        end

        it "allows access" do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'user without a smartcard session' do
        it "does not allow access" do
          subject

          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response['message']).to eql('Project requires smartcard login. Please login to GitLab using a smartcard.')
        end
      end

      context 'with the setting off' do
        before do
          stub_smartcard_setting(required_for_git_access: false)
        end

        it "allows access" do
          subject

          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'ip restriction' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project, freeze: false) { create(:project, :repository, namespace: group) }

      let(:params) do
        {
          key_id: key.id,
          project: project.full_path,
          gl_repository: "project-#{project.id}",
          action: 'git-upload-pack',
          protocol: 'ssh'
        }
      end

      let(:allowed_ip) { '150.168.0.1' }

      before do
        create(:ip_restriction, group: group, range: allowed_ip)
        stub_licensed_features(group_ip_restriction: true)

        project.add_developer(user)
      end

      context 'with or without check_ip parameter' do
        using RSpec::Parameterized::TableSyntax

        before do
          stub_feature_flags(log_git_streaming_audit_events: false)

          allow(Gitlab::Audit::Auditor).to receive(:audit)
        end

        where(:check_ip_present, :ip, :status, :should_set_client_ip) do
          false | nil           | 200 | false
          true  | '150.168.0.1' | 200 | true
          true  | '150.168.0.2' | 404 | false
        end

        with_them do
          subject do
            post(
              api('/internal/allowed'),
              params: check_ip_present ? params.merge(check_ip: ip) : params,
              headers: gitlab_shell_internal_api_request_header
            )
          end

          it 'modifies access' do
            subject

            expect(response).to have_gitlab_http_status(status)
          end

          it 'sends an audit event including the ip_address' do
            if should_set_client_ip
              expect(Gitlab::Audit::Auditor).to receive(:audit).with(a_hash_including(ip_address: ip))
            else
              expect(Gitlab::Audit::Auditor).not_to receive(:audit).with(a_hash_including(ip_address: ip))
            end

            subject
          end
        end
      end
    end

    context 'with gitaly context' do
      subject do
        post(
          api("/internal/allowed"),
          params: params,
          headers: gitlab_shell_internal_api_request_header
        )
      end

      let_it_be(:project, freeze: false) { create(:project, :repository) }

      let(:params) do
        {
          key_id: key.id,
          project: project.full_path,
          gl_repository: "project-#{project.id}",
          action: 'git-upload-pack',
          protocol: 'ssh',
          gitaly_client_context_bin: Base64.encode64(gitaly_context.to_json)
        }
      end

      let(:gitaly_context) { { key: :value } }

      before do
        project.add_developer(user)
      end

      it 'passes gitaly context to access checker' do
        expect(Gitlab::GitAccessProject).to receive(:new).with(
          key,
          project,
          'ssh',
          a_hash_including(gitaly_context: { 'key' => 'value' })
        ).and_call_original

        subject

        expect(response).to have_gitlab_http_status(:ok)
      end
    end

    context 'with a service account', :request_store do
      let_it_be(:project, freeze: false) { create(:project, :repository) }
      let_it_be(:other_user) { create(:user) }
      let_it_be(:service_account_user) { create(:user, :service_account, composite_identity_enforced: true) }

      let(:gitaly_context) do
        {
          'scoped-user-id' => user.id.to_s
        }.to_json
      end

      before do
        project.add_developer(service_account_user)
        project.add_developer(user)
      end

      def request
        post(
          api("/internal/allowed"),
          params: {
            user_id: service_account_user.id,
            project: full_path_for(project),
            gl_repository: gl_repository_for(project),
            action: 'git-upload-pack',
            protocol: 'ssh',
            gitaly_client_context_bin: Base64.encode64(gitaly_context)
          },
          headers: gitlab_shell_internal_api_request_header
        )
      end

      it 'returns 200 and links the composite identity' do
        expect(::Gitlab::Auth::Identity).to receive(:link_from_scoped_user_id).with(service_account_user, user.id).and_call_original

        request

        expect(response).to have_gitlab_http_status(:ok)
      end

      context 'with a scoped user with no access' do
        let(:gitaly_context) do
          {
            'scoped-user-id' => other_user.id.to_s
          }.to_json
        end

        it 'returns 404' do
          expect(::Gitlab::Auth::Identity).to receive(:link_from_scoped_user_id).with(service_account_user, other_user.id).and_call_original

          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with an unknown scoped user ID' do
        let(:gitaly_context) do
          {
            'scoped-user-id' => '0'
          }.to_json
        end

        it 'returns a 404' do
          request

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'with an invalid gitaly_context' do
        let(:gitaly_context) { "[]" }

        it 'returns 400' do
          request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end

      context 'with malformed gitaly_context' do
        let(:gitaly_context) { "\x00" }

        it 'returns 400' do
          request

          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end

    context 'maintenance mode enabled' do
      let_it_be(:project, freeze: false) { create(:project, :repository) }

      before do
        stub_maintenance_mode_setting(true)

        project.add_developer(user)
      end

      context 'when action is git push' do
        it 'returns forbidden' do
          push(key, project)

          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response["status"]).to be_falsey
          expect(json_response["message"]).to eq(
            'Git push is not allowed because this GitLab instance is currently in (read-only) maintenance mode.'
          )
          expect(user.reload.last_activity_on).to be_nil
        end
      end

      context 'when action is not git push' do
        it 'returns success' do
          pull(key, project)

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response["status"]).to be_truthy
        end
      end
    end

    context 'with Deploy Key authentication' do
      let_it_be(:project, freeze: false) { create(:project, :repository) }
      let_it_be(:key) { create(:deploy_key, user: user) }
      let_it_be(:deploy_keys_project) do
        create(:deploy_keys_project, :write_access, project: project, deploy_key: key)
      end

      before_all do
        project.add_developer(user)
      end

      it 'passes the deploy key to the auditor context' do
        # new log_git_streaming_audit_events FF will check need_git_audit_event? by new workflow,
        # so we need set it to be false to confirm the original workflow is used
        stub_feature_flags(log_git_streaming_audit_events: false)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(author: key))

        push(key, project)
      end

      it 'includes the deploy key details in the audit message' do
        stub_feature_flags(log_git_streaming_audit_events: false)

        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(message: hash_including(gl_key_type: 'deploy_key', gl_key_id: key.id))
        )

        push(key, project)
      end

      context 'when log_git_streaming_audit_events is enabled' do
        it 'does not passes the deploy key to the auditor context' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit).with(hash_including(author: key))

          push(key, project)
        end
      end
    end

    context 'git audit streaming event' do
      it_behaves_like 'sends git audit streaming event' do
        subject { pull(key, project) }
      end
    end

    context 'with excess repository size limits', :saas do
      let_it_be(:group) { create(:group) }
      let_it_be(:project, freeze: false) { create(:project, :repository, group: group) }

      let(:sha_with_2_mb_file) { 'bf12d2567099e26f59692896f73ac819bae45b00' }

      context 'with a public fork of a project' do
        let_it_be_with_refind(:project_fork) { create(:project, :public, :repository, group: group) }
        let_it_be(:fork_network) { create(:fork_network, root_project: project) }
        let_it_be(:fork_network_member) do
          create(:fork_network_member, project: project_fork,
            fork_network: fork_network, forked_from_project: project)
        end

        before_all do
          project_fork.add_developer(user)
        end

        context 'when the push size would exceed the size limit' do
          before do
            stub_ee_application_setting(check_namespace_plan: true)
            stub_ee_application_setting(namespace_storage_forks_cost_factor: 0.25)

            project_fork.update!(repository_size_limit: 4.megabytes)
            project_fork.statistics.update!(repository_size: 3.megabytes)
            project_fork.repository.delete_branch('2-mb-file')
          end

          it 'does not apply a cost factor to the push size and rejects the push' do
            push(key, project_fork, changes: "#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_2_mb_file} refs/heads/my_branch_2")

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response["status"]).to be(false)
            expect(json_response["message"]).to eq(
              "Your push to this repository cannot be completed as it would exceed " \
              "the allocated storage for your project. " \
              "Contact your GitLab administrator for more information."
            )
          end
        end
      end
    end

    context 'with a namespace storage size limit', :saas do
      let_it_be_with_refind(:group) { create(:group) }
      let_it_be(:project, freeze: false) { create(:project, :repository, :wiki_repo, group: group) }

      let(:sha_with_2_mb_file) { 'bf12d2567099e26f59692896f73ac819bae45b00' }

      before_all do
        project.add_developer(user)
        # Use create_or_replace_subscription because project.add_developer above
        # triggers Internal Events tracking, which auto-generates a FREE subscription
        create_or_replace_subscription(group, :ultimate)
        create(:namespace_root_storage_statistics, namespace: group)
        set_enforcement_limit(group, megabytes: 4)
      end

      before do
        enforce_namespace_storage_limit(group)
        stub_ee_application_setting(namespace_storage_forks_cost_factor: 0.25)
      end

      context 'with a project' do
        before do
          project.repository.delete_branch('2-mb-file')
        end

        context 'requests without changes' do
          it 'returns ok when the size limit has been exceeded' do
            set_used_storage(group, megabytes: 6)

            push(key, project, changes: '_any')

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["status"]).to be(true)
          end

          it 'returns ok when the size is under the limit' do
            set_used_storage(group, megabytes: 1)

            push(key, project, changes: '_any')

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["status"]).to be(true)
          end
        end

        context 'requests with changes' do
          let(:size_checker) { Namespaces::Storage::RootSize.new(group) }

          it 'rejects git push when the size limit has been exceeded' do
            set_used_storage(group, megabytes: 6)

            push(key, project)

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response["status"]).to be(false)
            expect(json_response["message"]).to eq(size_checker.error_message.push_error)
          end

          it 'rejects git push when the push size would exceed the limit' do
            set_used_storage(group, megabytes: 3)
            usage_guide = ::Gitlab::Routing.url_helpers.help_page_url('user/storage_usage_quotas.md', anchor: 'manage-storage-usage')
            read_only_guide = ::Gitlab::Routing.url_helpers.help_page_url('user/read_only_namespaces.md', anchor: 'restricted-actions')

            push(key, project, changes: "#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_2_mb_file} refs/heads/my_branch_2")

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response["status"]).to be(false)
            expect(json_response["message"]).to eq(
              "Your push to this repository has been rejected because " \
              "it would exceed the namespace storage limit of 4 MiB. " \
              "Reduce your namespace storage or purchase additional storage." \
              "To manage storage, or purchase additional storage, see #{usage_guide}. " \
              "To learn more about restricted actions, see #{read_only_guide}"
            )
          end

          it 'accepts git push when the size is under the limit' do
            set_used_storage(group, megabytes: 1)

            push(key, project, changes: "#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_2_mb_file} refs/heads/my_branch_2")

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["status"]).to be(true)
          end
        end
      end

      context 'with a public fork of a project' do
        let_it_be(:project_fork) { create(:project, :public, :repository, group: group) }
        let_it_be(:fork_network) { create(:fork_network, root_project: project) }
        let_it_be(:fork_network_member) do
          create(:fork_network_member, project: project_fork,
            fork_network: fork_network, forked_from_project: project)
        end

        before do
          project_fork.add_developer(user)
          project_fork.repository.delete_branch('2-mb-file')
        end

        it 'accepts git push to a fork when the push size with the cost factor applied is under the limit' do
          set_used_storage(group, megabytes: 3)

          push(key, project_fork, changes: "#{Gitlab::Git::SHA1_BLANK_SHA} #{sha_with_2_mb_file} refs/heads/my_branch_2")

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response["status"]).to be(true)
        end
      end

      context 'with a snippet' do
        let_it_be(:project_snippet) { create(:project_snippet, :repository, author: user, project: project) }

        let(:snippet_changes) { "#{TestEnv::BRANCH_SHA['snippet/single-file']} #{TestEnv::BRANCH_SHA['snippet/edit-file']} refs/heads/snippet/edit-file" }

        it 'rejects git push when the size limit has been exceeded' do
          set_used_storage(group, megabytes: 6)

          push(key, project_snippet, changes: snippet_changes)

          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response["status"]).to be(false)
          expect(json_response["message"]).to eq("You are not allowed to update this snippet.")
        end
      end

      context 'with a wiki' do
        let_it_be(:wiki, freeze: false) { create(:project_wiki, project: project) }

        it 'rejects git push when the size limit has been exceeded' do
          set_used_storage(group, megabytes: 6)

          push(key, wiki)

          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response["status"]).to be(false)
          expect(json_response["message"]).to eq("You are not allowed to write to this project's wiki.")
        end
      end
    end

    context 'when namespace storage size limits are enabled', :saas do
      let_it_be_with_refind(:group) { create(:group_with_plan, plan: :ultimate_plan) }
      let_it_be(:project, freeze: false) { create(:project, :repository, group: group) }

      let(:sha_with_2_mb_file) { 'bf12d2567099e26f59692896f73ac819bae45b00' }

      before_all do
        project.add_developer(user)
      end

      before do
        stub_application_setting(enforce_namespace_storage_limit: true)
        stub_application_setting(automatic_purchased_storage_allocation: true)
        stub_feature_flags(namespace_storage_limit: true)
      end

      context 'with a project in a paid namespace' do
        context 'requests with changes' do
          it 'accepts git push when the project repository size limit has been exceeded but is within the additional purchased storage size' do
            group.update!(additional_purchased_storage_size: 3)
            project.update!(repository_size_limit: 4.megabytes)
            project.statistics.update!(repository_size: 6.megabytes)

            push(key, project)

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response["status"]).to be(true)
          end
        end
      end
    end

    context 'when authenticated via an SSH certificate' do
      let_it_be_with_refind(:root_group) { create(:group) }
      let_it_be(:group) { create(:group, parent: root_group) }
      let_it_be(:project, freeze: false) { create(:project, :public, :repository, group: group) }

      let(:namespace_path) { nil }

      let(:params) do
        {
          action: "git-upload-pack",
          user_id: user.id,
          project: project.full_path,
          protocol: 'ssh',
          changes: '_any',
          namespace_path: namespace_path
        }
      end

      def check_allowed
        post(
          api("/internal/allowed"),
          params: params,
          headers: gitlab_shell_internal_api_request_header
        )
      end

      before do
        stub_licensed_features(ssh_certificates: group)
      end

      context 'when group is not specified' do
        it 'returns success response' do
          check_allowed

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when auth via SSH certificates is enforced' do
          before do
            root_group.namespace_settings.enforce_ssh_certificates = true
            root_group.save!
          end

          it 'returns an unauthorized error response' do
            check_allowed

            expect(response).to have_gitlab_http_status(:unauthorized)
            expect(json_response['status']).to be(false)
            expect(json_response['message']).to eq('You are not allowed to access projects in this namespace.')
          end

          context 'when the changes list is specified' do
            let(:params) do
              super().merge({
                changes: "#{Gitlab::Git::SHA1_BLANK_SHA} 570e7b2abdd848b95f2f578043fc23bd6f6fd24d refs/heads/mybranch"
              })
            end

            it 'returns success response' do
              check_allowed

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          context 'when service account is used' do
            let(:params) do
              super().merge({
                user_id: create(:user, :service_account).id
              })
            end

            it 'returns success response' do
              check_allowed

              expect(response).to have_gitlab_http_status(:ok)
            end
          end

          context 'when deploy key is used' do
            let(:params) do
              super().without(:user_id).merge({
                key_id: create(:deploy_key).id
              })
            end

            it 'returns success response' do
              check_allowed

              expect(response).to have_gitlab_http_status(:ok)
            end
          end
        end
      end

      context 'when non-root group is specified' do
        let(:namespace_path) { group.full_path }

        it 'returns an unauthorized error response' do
          check_allowed

          expect(response).to have_gitlab_http_status(:unauthorized)
          expect(json_response['status']).to be(false)
          expect(json_response['message']).to eq('You are not allowed to access projects in this namespace.')
        end
      end

      context 'when root group is specified' do
        let(:namespace_path) { root_group.full_path }

        it 'is successful' do
          check_allowed

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when ssh_certificates licensed feature is not available' do
          it 'returns an unauthorized error response' do
            stub_licensed_features(ssh_certificates: false)

            check_allowed

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end

        context 'when personal project is accessed' do
          let_it_be(:project, freeze: false) { create(:project, :public, :repository, namespace: user.namespace) }

          it 'returns an unauthorized error response' do
            check_allowed

            expect(response).to have_gitlab_http_status(:unauthorized)
          end
        end
      end
    end

    context 'when a GeoCustomSshError is raised', :geo do
      let_it_be(:project, freeze: false) { create(:project, :repository) }

      let(:custom_payload) do
        {
          'action' => 'geo_proxy_to_primary',
          'data' => {
            'api_endpoints' => ['/api/v4/geo/proxy_git_ssh/info_refs_upload_pack', '/api/v4/geo/proxy_git_ssh/upload_pack'],
            'primary_repo' => "http://primary.example.com/#{project.full_path}.git"
          }
        }
      end

      let(:console_messages) do
        [
          "This request to a Geo secondary node will be forwarded to the",
          "Geo primary node:",
          "",
          "  git@primary.example.com:#{project.full_path}.git"
        ]
      end

      # Create a real CustomAction instance with positional arguments
      let(:custom_action) do
        result = Gitlab::GitAccessResult::CustomAction.new(custom_payload, console_messages)
        # Make sure it responds to success? with true
        allow(result).to receive(:success?).and_return(true)
        result
      end

      before do
        project.add_developer(user)
        stub_current_geo_node(secondary_node)

        # rubocop:disable RSpec/AnyInstanceOf -- Cannot use allow_next_instance_of with modules that are included in other classes
        allow_any_instance_of(API::Helpers::InternalHelpers).to receive(:access_check_result) do
          raise Gitlab::GitAccess::GeoCustomSshError
        end
        # rubocop:enable RSpec/AnyInstanceOf
        allow_next_instance_of(::Gitlab::GitAccess) do |git_access|
          allow(git_access).to receive(:geo_custom_ssh_action).and_return(custom_action)
        end
      end

      it 'handles the error and returns a custom action' do
        post(
          api("/internal/allowed"),
          params: {
            key_id: key.id,
            project: project.full_path,
            gl_repository: "project-#{project.id}",
            action: 'git-upload-pack',
            protocol: 'ssh'
          },
          headers: gitlab_shell_internal_api_request_header
        )

        expect(response).to have_gitlab_http_status(:multiple_choices) # or :multiple_choice or 300
        expect(json_response['status']).to be true
        expect(json_response['gl_console_messages']).to eq(console_messages)
        expect(json_response['payload']).to eq(custom_payload)
      end
    end
  end

  describe "POST /internal/lfs_authenticate", :geo do
    let(:project) { create(:project, :repository) }

    context 'for a secondary node' do
      before do
        stub_lfs_setting(enabled: true)
        stub_current_geo_node(secondary_node)
        project.add_developer(user)
      end

      it 'returns the repository_http_path at the primary node' do
        expect(Project).to receive(:find_by_full_path).and_return(project)

        lfs_auth_user(user.id, project)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['repository_http_path']).to eq(geo_primary_http_url_to_repo(project))
      end
    end

    def lfs_auth_user(user_id, project)
      post(
        api("/internal/lfs_authenticate"),
        params: {
          user_id: user_id,
          project: project.full_path
        },
        headers: gitlab_shell_internal_api_request_header
      )
    end
  end

  describe 'POST /internal/two_factor_recovery_codes' do
    subject(:request_two_factor_recovery_codes) do
      post api('/internal/two_factor_recovery_codes'),
        params: { key_id: key.id },
        headers: gitlab_shell_internal_api_request_header
    end

    context 'for enterprise users', :saas do
      before do
        stub_licensed_features(disable_ssh_keys: true)
        stub_saas_features(disable_ssh_keys: true)
      end

      let_it_be_with_reload(:group) { create(:group) }

      context 'when two-factor is enabled' do
        let_it_be(:user, freeze: false) { create(:enterprise_user, :two_factor, enterprise_group: group) }
        let_it_be(:key) { create(:key, user: user) }

        it 'returns new recovery codes' do
          request_two_factor_recovery_codes

          expect(json_response['success']).to be_truthy
        end

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it 'returns an error message', :aggregate_failures do
            request_two_factor_recovery_codes

            expect(json_response['success']).to be_falsey
            expect(json_response['message']).to eq('SSH keys are disabled for this user')
          end
        end
      end
    end
  end

  describe 'POST /internal/two_factor_config' do
    subject(:request_two_factor_config) do
      post api('/internal/two_factor_config'),
        params: { key_id: key.id },
        headers: gitlab_shell_internal_api_request_header
    end

    context 'for enterprise users', :saas do
      before do
        stub_licensed_features(disable_ssh_keys: true)
        stub_saas_features(disable_ssh_keys: true)
      end

      let_it_be_with_reload(:group) { create(:group) }

      context 'when two-factor is enabled' do
        let_it_be(:user, freeze: false) { create(:enterprise_user, :two_factor, enterprise_group: group) }
        let_it_be(:key) { create(:key, user: user) }

        it 'returns user two factor config' do
          request_two_factor_config

          expect(json_response['success']).to be_truthy
        end

        context 'when SSH Keys are disabled by the group' do
          before do
            group.namespace_settings.update!(disable_ssh_keys: true)
          end

          it 'returns an error message', :aggregate_failures do
            request_two_factor_config

            expect(json_response['success']).to be_falsey
            expect(json_response['message']).to eq('SSH keys are disabled for this user')
          end
        end
      end
    end
  end

  describe 'POST /internal/personal_access_token', :system_access, :with_current_organization do
    let_it_be(:key) { create(:key, user: user) }

    let(:instance_level_max_personal_access_token_lifetime) { nil }

    before do
      stub_licensed_features(personal_access_token_expiration_policy: !!instance_level_max_personal_access_token_lifetime)
      stub_application_setting(max_personal_access_token_lifetime: instance_level_max_personal_access_token_lifetime)
    end

    context 'with a max token lifetime on the instance' do
      let(:instance_level_max_personal_access_token_lifetime) { 10 }

      it 'returns an error message when the expiry date exceeds the max token lifetime', :freeze_time do
        max_expiry_date = Date.current + instance_level_max_personal_access_token_lifetime
        post api('/internal/personal_access_token'),
          params: {
            key_id: key.id,
            name: 'newtoken',
            scopes: %w[read_api read_repository],
            expires_at: max_expiry_date + 1
          },
          headers: gitlab_shell_internal_api_request_header

        aggregate_failures do
          expect(json_response['success']).to be(false)
          expect(json_response['message']).to eq("Failed to create token: Expiration date must be before #{max_expiry_date.iso8601}")
        end
      end

      it 'returns a valid token when the expiry date does not exceed the max token lifetime' do
        expires_at = instance_level_max_personal_access_token_lifetime.days.from_now.to_date.to_s

        post api('/internal/personal_access_token'),
          params: {
            key_id: key.id,
            name: 'newtoken',
            scopes: %w[read_api read_repository],
            expires_at: expires_at
          },
          headers: gitlab_shell_internal_api_request_header

        aggregate_failures do
          expect(json_response['success']).to be(true)
          expect(json_response['token']).to start_with(PersonalAccessToken.token_prefix)
          expect(json_response['scopes']).to match_array(%w[read_api read_repository])
          expect(json_response['expires_at']).to eq(expires_at)
        end
      end
    end

    context 'for enterprise users', :saas do
      before do
        stub_licensed_features(disable_ssh_keys: true)
        stub_saas_features(disable_ssh_keys: true)
      end

      let_it_be_with_reload(:group) { create(:group) }

      let_it_be(:user, freeze: false) { create(:enterprise_user, enterprise_group: group) }
      let_it_be(:key) { create(:key, user: user) }

      it 'returns new token' do
        post api('/internal/personal_access_token'),
          params: {
            key_id: key.id,
            name: 'newtoken',
            scopes: %w[read_api read_repository],
            expires_at: Date.tomorrow
          },
          headers: gitlab_shell_internal_api_request_header

        expect(json_response['success']).to be_truthy
      end

      context 'when SSH Keys are disabled by the group' do
        before do
          group.namespace_settings.update!(disable_ssh_keys: true)
        end

        it 'returns an error message', :aggregate_failures do
          post api('/internal/personal_access_token'),
            params: {
              key_id: key.id,
              name: 'newtoken',
              scopes: %w[read_api read_repository],
              expires_at: Date.tomorrow
            },
            headers: gitlab_shell_internal_api_request_header

          expect(json_response['success']).to be_falsey
          expect(json_response['message']).to eq('SSH keys are disabled for this user')
        end
      end
    end
  end

  describe 'POST /internal/two_factor_manual_otp_check' do
    let(:key) { create(:key, user: user) }

    let(:key_id) { key.id }
    let(:otp) { '123456' }

    before do
      stub_feature_flags(two_factor_for_cli: true)
      stub_licensed_features(git_two_factor_enforcement: true)
    end

    subject do
      post api('/internal/two_factor_manual_otp_check'),
        params: { key_id: key_id, otp_attempt: otp },
        headers: gitlab_shell_internal_api_request_header
    end

    it_behaves_like 'actor key validations'

    context 'when the key is a deploy key' do
      let(:key_id) { create(:deploy_key).id }

      it 'returns an error message' do
        subject

        expect(json_response['success']).to be_falsey
        expect(json_response['message']).to eq('Deploy keys cannot be used for Two Factor')
      end
    end

    context 'when the two factor is enabled' do
      before do
        allow_any_instance_of(User).to receive(:two_factor_enabled?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf
      end

      context 'when the OTP is valid' do
        it 'registers a new OTP session and returns success' do
          allow_next_instance_of(Users::ValidateManualOtpService) do |service|
            allow(service).to receive(:execute).with(otp).and_return(status: :success)
          end

          expect_next_instance_of(::Gitlab::Auth::Otp::SessionEnforcer) do |session_enforcer|
            expect(session_enforcer).to receive(:update_session).once
          end

          subject

          expect(json_response['success']).to be_truthy
        end

        context 'for enterprise users', :saas do
          before do
            stub_licensed_features(git_two_factor_enforcement: true, disable_ssh_keys: true)
            stub_saas_features(disable_ssh_keys: true)
          end

          let_it_be_with_reload(:group) { create(:group) }

          let_it_be(:user, freeze: false) { create(:enterprise_user, :two_factor, enterprise_group: group) }
          let_it_be(:key) { create(:key, user: user) }

          it 'registers a new OTP session and returns success' do
            allow_next_instance_of(Users::ValidateManualOtpService) do |service|
              allow(service).to receive(:execute).with(otp).and_return(status: :success)
            end

            expect_next_instance_of(::Gitlab::Auth::Otp::SessionEnforcer) do |session_enforcer|
              expect(session_enforcer).to receive(:update_session).once
            end

            subject

            expect(json_response['success']).to be_truthy
          end

          context 'when SSH Keys are disabled by the group' do
            before do
              group.namespace_settings.update!(disable_ssh_keys: true)
            end

            it 'does not register a new OTP session and return an error message', :aggregate_failures do
              expect(Users::ValidateManualOtpService).not_to receive(:new)

              subject

              expect(json_response['success']).to be_falsey
              expect(json_response['message']).to eq('SSH keys are disabled for this user')
            end
          end
        end
      end

      context 'when the OTP is invalid' do
        before do
          allow_next_instance_of(Users::ValidateManualOtpService) do |service|
            allow(service).to receive(:execute).with(otp).and_return(status: :error)
          end
        end

        it_behaves_like 'an auditable failed authentication' do
          let(:operation) { subject }
          let(:method) { 'OTP' }
        end

        it 'is not success' do
          subject

          expect(json_response['success']).to be_falsey
        end

        it "locks the user out after maximum attempts is reached" do
          user.update!(failed_attempts: User.maximum_attempts.pred)

          # make invalid request to lock user before next request
          post api('/internal/two_factor_manual_otp_check'),
            params: { key_id: key_id, otp_attempt: otp },
            headers: gitlab_shell_internal_api_request_header

          # user is now locked
          subject

          expect(json_response['success']).to be_falsey
          expect(json_response['message']).to eq 'Your account is locked'
        end

        it "logs the failure" do
          allow(Gitlab::AppLogger).to receive(:info)

          expect(::Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'Failed OTP login',
              user_id: user.id,
              failed_attempts: user.failed_attempts + 1,
              ip: '127.0.0.1'
            ))
            .and_call_original

          subject
        end
      end
    end

    context 'when the two factor is disabled' do
      before do
        allow_any_instance_of(User).to receive(:two_factor_enabled?).and_return(false) # rubocop:disable RSpec/AnyInstanceOf
      end

      it 'returns an error message' do
        subject

        expect(json_response['success']).to be_falsey
        expect(json_response['message']).to eq 'Two-factor authentication is not enabled for this user'
      end
    end

    context 'feature flag is disabled' do
      before do
        stub_feature_flags(two_factor_for_cli: false)
      end

      context 'when two-factor is enabled for the user' do
        it 'returns user two factor config' do
          allow_next_instance_of(User) do |instance|
            allow(instance).to receive(:two_factor_enabled?).and_return(true)
          end

          subject

          expect(json_response['success']).to be_falsey
        end
      end
    end

    context 'licensed feature is not available' do
      before do
        stub_licensed_features(git_two_factor_enforcement: false)
      end

      context 'when two-factor is enabled for the user' do
        it 'returns user two factor config' do
          allow_next_instance_of(User) do |instance|
            allow(instance).to receive(:two_factor_enabled?).and_return(true)
          end

          subject

          expect(json_response['success']).to be_falsey
        end
      end
    end
  end

  describe 'POST /internal/two_factor_push_otp_check' do
    let(:key) { create(:key, user: user) }

    let(:key_id) { key.id }
    let(:otp) { '123456' }

    before do
      stub_feature_flags(two_factor_for_cli: true)
      stub_licensed_features(git_two_factor_enforcement: true)
    end

    subject do
      post api('/internal/two_factor_push_otp_check'),
        params: { key_id: key_id, otp_attempt: otp },
        headers: gitlab_shell_internal_api_request_header
    end

    it_behaves_like 'actor key validations'

    context 'when the key is a deploy key' do
      let(:key_id) { create(:deploy_key).id }

      it 'returns an error message' do
        subject

        expect(json_response['success']).to be_falsey
        expect(json_response['message']).to eq('Deploy keys cannot be used for Two Factor')
      end
    end

    context 'when the two factor is enabled' do
      before do
        allow_any_instance_of(User).to receive(:two_factor_enabled?).and_return(true) # rubocop:disable RSpec/AnyInstanceOf
      end

      context 'when the OTP is valid' do
        it 'registers a new OTP session and returns success' do
          allow_next_instance_of(Users::ValidatePushOtpService) do |service|
            allow(service).to receive(:execute).and_return(status: :success)
          end

          expect_next_instance_of(::Gitlab::Auth::Otp::SessionEnforcer) do |session_enforcer|
            expect(session_enforcer).to receive(:update_session).once
          end

          subject

          expect(json_response['success']).to be_truthy
        end

        context 'for enterprise users', :saas do
          before do
            stub_licensed_features(git_two_factor_enforcement: true, disable_ssh_keys: true)
            stub_saas_features(disable_ssh_keys: true)
          end

          let_it_be_with_reload(:group) { create(:group) }

          let_it_be(:user, freeze: false) { create(:enterprise_user, :two_factor, enterprise_group: group) }
          let_it_be(:key) { create(:key, user: user) }

          it 'registers a new OTP session and returns success' do
            allow_next_instance_of(Users::ValidatePushOtpService) do |service|
              allow(service).to receive(:execute).and_return(status: :success)
            end

            expect_next_instance_of(::Gitlab::Auth::Otp::SessionEnforcer) do |session_enforcer|
              expect(session_enforcer).to receive(:update_session).once
            end

            subject

            expect(json_response['success']).to be_truthy
          end

          context 'when SSH Keys are disabled by the group' do
            before do
              group.namespace_settings.update!(disable_ssh_keys: true)
            end

            it 'does not register a new OTP session and return an error message', :aggregate_failures do
              expect(Users::ValidatePushOtpService).not_to receive(:new)

              subject

              expect(json_response['success']).to be_falsey
              expect(json_response['message']).to eq('SSH keys are disabled for this user')
            end
          end
        end
      end

      context 'when the OTP is invalid' do
        it 'is not success' do
          allow_next_instance_of(Users::ValidatePushOtpService) do |service|
            allow(service).to receive(:execute).and_return(status: :error)
          end

          subject

          expect(json_response['success']).to be_falsey
        end
      end
    end

    context 'when the two factor is disabled' do
      before do
        allow_any_instance_of(User).to receive(:two_factor_enabled?).and_return(false) # rubocop:disable RSpec/AnyInstanceOf
      end

      it 'returns an error message' do
        subject

        expect(json_response['success']).to be_falsey
        expect(json_response['message']).to eq 'Two-factor authentication is not enabled for this user'
      end
    end

    context 'feature flag is disabled' do
      before do
        stub_feature_flags(two_factor_for_cli: false)
      end

      context 'when two-factor is enabled for the user' do
        it 'returns user two factor config' do
          allow_next_instance_of(User) do |instance|
            allow(instance).to receive(:two_factor_enabled?).and_return(true)
          end

          subject

          expect(json_response['success']).to be_falsey
        end
      end
    end

    context 'licensed feature is not available' do
      before do
        stub_licensed_features(git_two_factor_enforcement: false)
      end

      context 'when two-factor is enabled for the user' do
        it 'returns user two factor config' do
          allow_next_instance_of(User) do |instance|
            allow(instance).to receive(:two_factor_enabled?).and_return(true)
          end

          subject

          expect(json_response['success']).to be_falsey
        end
      end
    end
  end

  describe "GET /internal/authorized_certs" do
    let_it_be(:group) { create(:group) }
    let_it_be(:cert) { create(:group_ssh_certificate, group: group) }

    let(:params) { { key: cert.fingerprint, user_identifier: user.username } }

    before do
      stub_licensed_features(ssh_certificates: group)
    end

    context 'when user is a member of the group' do
      before do
        group.add_developer(user)
      end

      context 'when the user is not an enterprise user of the group' do
        it 'returns 403' do
          get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

          expect(response).to have_gitlab_http_status(:forbidden)
          expect(json_response['message']).to eq('Not an Enterprise User of the group')
        end
      end

      context 'when the user is an enterprise user of the group' do
        let(:user) { create(:enterprise_user, enterprise_group: group) }

        it 'finds the cert and the user' do
          get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['success']).to be(true)
          expect(json_response['namespace']).to eq(group.full_path)
          expect(json_response['username']).to eq(user.username)
        end
      end

      context 'when cert is not found' do
        let(:params) { super().merge(key: 'invalid') }

        it 'returns 404' do
          get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('Certificate Not Found')
        end
      end

      context 'when user is not found' do
        let(:params) { super().merge(user_identifier: 'invalid') }

        it 'returns 404' do
          get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('User Not Found')
        end
      end
    end

    context 'when user is not a member of the group' do
      it 'returns 404' do
        get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('User Not Found')
      end
    end

    context 'when ssh_certificates licensed feature is not available' do
      it 'returns error' do
        stub_licensed_features(ssh_certificates: false)

        get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

        expect(response).to have_gitlab_http_status(:forbidden)
        expect(json_response['message']).to eq('Feature is not available')
      end
    end

    context 'when multiple groups share the same CA fingerprint' do
      let_it_be(:other_group) { create(:group) }
      let_it_be(:other_cert) { create(:group_ssh_certificate, group: other_group, key: cert.key) }
      let_it_be(:other_user) { create(:enterprise_user, enterprise_group: other_group, developer_of: other_group) }

      let(:params) { { key: cert.fingerprint, user_identifier: other_user.username } }

      before do
        stub_licensed_features(ssh_certificates: true)
      end

      it 'resolves to the correct group for the user' do
        get(api('/internal/authorized_certs'), params: params, headers: gitlab_shell_internal_api_request_header)

        expect(response).to have_gitlab_http_status(:ok)
        expect(json_response['success']).to be(true)
        expect(json_response['namespace']).to eq(other_group.full_path)
        expect(json_response['username']).to eq(other_user.username)
      end
    end
  end
end
