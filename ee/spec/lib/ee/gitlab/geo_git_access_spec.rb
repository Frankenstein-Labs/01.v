# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::GeoGitAccess, feature_category: :geo_replication do
  let_it_be(:project) { create(:project, :small_repo) }
  let(:user) { create(:user) }
  let(:cmd) { 'git-upload-pack' }

  let(:test_class) do
    Class.new(Gitlab::GitAccess) do
      prepend EE::Gitlab::GeoGitAccess

      def initialize(actor, container, protocol, cmd, authentication_abilities: [])
        super(actor, container, protocol, authentication_abilities: authentication_abilities)
        @cmd = cmd
      end

      # Make check_custom_ssh_action! public for testing
      public :check_custom_ssh_action!
    end
  end

  let(:instance) { test_class.new(user, project, 'ssh', cmd) }

  before do
    allow(Gitlab::Database).to receive(:read_only?).and_return(true)
    allow(Gitlab::Geo).to receive(:secondary_with_primary?).and_return(true)
  end

  describe '#forward_ssh_git_request_to_primary?' do
    it 'returns true when all conditions are met' do
      expect(instance.forward_ssh_git_request_to_primary?).to be true
    end

    context 'when protocol is not SSH' do
      let(:instance) { test_class.new(user, project, 'http', cmd) }

      it 'returns false' do
        expect(instance.forward_ssh_git_request_to_primary?).to be false
      end
    end
  end

  describe '#geo_custom_ssh_action' do
    before do
      allow(Gitlab::Geo).to receive(:current_node).and_return(create(:geo_node))
      allow(instance).to receive_messages(
        primary_http_repo_internal_url: 'http://primary.gitlab.com/repo.git',
        custom_action_api_endpoints_for: ['/api/endpoint1', '/api/endpoint2'],
        primary_ssh_url_to_repo: 'git@primary.gitlab.com:group/project.git'
      )
    end

    it 'returns a CustomAction with the correct payload' do
      result = instance.geo_custom_ssh_action

      expect(result).to be_a(Gitlab::GitAccessResult::CustomAction)
      expect(result.payload).to include(
        'action' => 'geo_proxy_to_primary',
        'data' => hash_including(
          'api_endpoints' => ['/api/endpoint1', '/api/endpoint2'],
          'primary_repo' => 'http://primary.gitlab.com/repo.git'
        )
      )
    end
  end

  describe '#check_custom_ssh_action!' do
    before do
      allow(instance).to receive(:forward_ssh_git_request_to_primary?).and_return(true)
    end

    it 'raises GeoCustomSshError when conditions are met' do
      error_message = "The repo does not exist or is out-of-date on this secondary site"
      expect { instance.check_custom_ssh_action! }.to raise_error(
        Gitlab::GitAccess::GeoCustomSshError,
        error_message)
    end

    context 'when conditions are not met' do
      before do
        allow(instance).to receive(:forward_ssh_git_request_to_primary?).and_return(false)
      end

      it 'does not raise an error' do
        expect { instance.check_custom_ssh_action! }.not_to raise_error
      end
    end
  end

  describe '#actor_gl_id_prefix' do
    context "when the actor is the user's SSH key" do
      let(:key) { create(:key, user: user) }

      let(:instance) { test_class.new(key, project, 'ssh', cmd) }

      it "returns 'key' prefix" do
        expect(instance.send(:actor_gl_id_prefix)).to eq('key')
      end
    end

    context 'when the actor is a DeployKey' do
      let(:deploy_key) { create(:deploy_key, user: user) }

      let(:instance) { test_class.new(deploy_key, project, 'ssh', cmd) }

      it "returns 'key' prefix" do
        expect(instance.send(:actor_gl_id_prefix)).to eq('key')
      end
    end

    context 'when the actor is :geo' do
      let(:instance) { test_class.new(:geo, project, 'ssh', cmd) }

      it 'raises a ForbiddenError' do
        error_message = "Unexpected actor :geo. Secondary sites don't receive Git requests from other Geo sites."
        expect { instance.send(:actor_gl_id_prefix) }.to raise_error(
          Gitlab::GitAccess::ForbiddenError,
          error_message)
      end
    end

    context 'when the actor is :ci' do
      let(:instance) { test_class.new(:ci, project, 'ssh', cmd) }

      it 'raises a ForbiddenError' do
        error_message = 'Unexpected actor :ci. CI requests use Git over HTTP.'
        expect { instance.send(:actor_gl_id_prefix) }.to raise_error(
          Gitlab::GitAccess::ForbiddenError,
          error_message)
      end
    end

    context 'when the actor is an unaccounted for type' do
      let(:instance) { test_class.new(:foobar, project, 'ssh', cmd) }

      it 'raises a ForbiddenError' do
        expect { instance.send(:actor_gl_id_prefix) }.to raise_error(
          Gitlab::GitAccess::ForbiddenError,
          'Unknown type of actor')
      end
    end

    context 'when the actor is a user' do
      let(:user) { create(:user) }
      let(:instance) { test_class.new(user, project, 'ssh', cmd) }
      let(:current_replication_lag) { nil }

      before do
        allow(Gitlab::Geo).to receive(:current_node).and_return(create(:geo_node))
        allow(instance).to receive_messages(
          primary_http_repo_internal_url: 'http://primary.gitlab.com/repo.git',
          primary_ssh_url_to_repo: 'git@primary.gitlab.com:group/project.git')
      end

      it "returns 'user' prefix" do
        expect(instance.send(:actor_gl_id_prefix)).to eq('user')
      end

      context 'for a repository that has been replicated' do
        before do
          allow_next_instance_of(Gitlab::Geo::HealthCheck) do |instance|
            allow(instance).to receive(:db_replication_lag_seconds).and_return(current_replication_lag)
          end
        end

        context 'when there is no DB replication lag' do
          let(:current_replication_lag) { 0 }

          it 'does not include a replication lag message in the console messages' do
            result = instance.geo_custom_ssh_action

            expect(result.console_messages).not_to include('Current replication lag: 7 seconds')
          end
        end

        context 'when there is DB replication lag > 0' do
          let(:current_replication_lag) { 7 }

          it 'includes a replication lag message in the console messages' do
            result = instance.geo_custom_ssh_action

            expect(result.console_messages).to include('Current replication lag: 7 seconds')
          end
        end
      end

      context 'for a repository that has yet to be replicated' do
        let(:project_no_repo) { create(:project) }
        let(:instance) { test_class.new(user, project_no_repo, 'ssh', cmd) }
        let(:current_replication_lag) { 0 }

        before do
          allow(instance).to receive_messages(
            custom_action_api_endpoints_for: [
              '/api/v4/geo/proxy_git_ssh/info_refs_upload_pack',
              '/api/v4/geo/proxy_git_ssh/upload_pack'
            ],
            primary_http_repo_internal_url: "http://primary.gitlab.com/#{project_no_repo.full_path}.git",
            primary_ssh_url_to_repo: "git@primary.gitlab.com:#{project_no_repo.full_path}.git",
            proxy_direct_to_primary_headers: { 'Authorization' => 'Bearer token' }
          )

          allow_next_instance_of(Gitlab::Geo::HealthCheck) do |instance|
            allow(instance).to receive(:db_replication_lag_seconds).and_return(current_replication_lag)
          end
        end

        it 'returns a custom action with the expected payload and messages' do
          expected_payload = {
            "action" => "geo_proxy_to_primary",
            "data" => {
              "api_endpoints" => [
                "/api/v4/geo/proxy_git_ssh/info_refs_upload_pack",
                "/api/v4/geo/proxy_git_ssh/upload_pack"
              ],
              "primary_repo" => "http://primary.gitlab.com/#{project_no_repo.full_path}.git",
              "geo_proxy_fetch_ssh_direct_to_primary" => true,
              "geo_proxy_push_ssh_direct_to_primary" => true,
              "request_headers" => include('Authorization')
            }
          }
          expected_console_messages = [
            "This request to a Geo secondary node will be forwarded to the",
            "Geo primary node:",
            "",
            "  git@primary.gitlab.com:#{project_no_repo.full_path}.git"
          ]

          result = instance.geo_custom_ssh_action

          expect(result).to be_a(Gitlab::GitAccessResult::CustomAction)
          expect(result.payload).to include(expected_payload)
          expect(result.console_messages).to eq(expected_console_messages)
        end
      end
    end
  end

  describe 'git push' do
    context 'for a secondary' do
      let(:cmd) { 'git-receive-pack' }

      before do
        allow(Gitlab::Database).to receive(:read_only?).and_return(true)
        allow(Gitlab::Geo).to receive(:secondary_with_primary?).and_return(true)
      end

      context 'when the request is signed by a Geo site' do
        let(:instance) { test_class.new(:geo, project, 'ssh', cmd) }

        it 'raises a ForbiddenError' do
          error_message = "Unexpected actor :geo. Secondary sites don't receive Git requests from other Geo sites."
          expect { instance.send(:actor_gl_id_prefix) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            error_message
          )
        end
      end

      context 'when the actor is CI' do
        let(:instance) { test_class.new(:ci, project, 'ssh', cmd) }

        it 'raises a ForbiddenError' do
          error_message = 'Unexpected actor :ci. CI requests use Git over HTTP.'
          expect { instance.send(:actor_gl_id_prefix) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            error_message
          )
        end
      end

      context 'when the request is by an unaccounted for type of actor' do
        let(:instance) { test_class.new(:foobar, project, 'ssh', cmd) }

        it 'raises a ForbiddenError' do
          expect { instance.send(:actor_gl_id_prefix) }.to raise_error(
            Gitlab::GitAccess::ForbiddenError,
            'Unknown type of actor'
          )
        end
      end

      context 'when the actor is a DeployKey' do
        let(:user) { create(:user, developer_of: project) }
        let(:deploy_key) { create(:deploy_key, user: user) }
        let(:instance) { test_class.new(deploy_key, project, 'ssh', cmd) }

        before do
          deploy_key.deploy_keys_projects.create!(project: project, can_push: true)

          allow(instance).to receive_messages(
            custom_action_api_endpoints_for: [
              '/api/v4/geo/proxy_git_ssh/info_refs_receive_pack',
              '/api/v4/geo/proxy_git_ssh/receive_pack'
            ],
            primary_http_repo_internal_url: "http://primary.gitlab.com/#{project.full_path}.git",
            primary_ssh_url_to_repo: "git@primary.gitlab.com:#{project.full_path}.git",
            proxy_direct_to_primary_headers: { 'Authorization' => 'Bearer token' }
          )
        end

        it 'returns a custom action' do
          expected_payload = {
            "action" => "geo_proxy_to_primary",
            "data" => {
              "api_endpoints" => [
                "/api/v4/geo/proxy_git_ssh/info_refs_receive_pack",
                "/api/v4/geo/proxy_git_ssh/receive_pack"
              ],
              "primary_repo" => "http://primary.gitlab.com/#{project.full_path}.git",
              "geo_proxy_fetch_ssh_direct_to_primary" => true,
              "geo_proxy_push_ssh_direct_to_primary" => true,
              "request_headers" => include('Authorization')
            }
          }
          expected_console_messages = [
            "This request to a Geo secondary node will be forwarded to the",
            "Geo primary node:",
            "",
            "  git@primary.gitlab.com:#{project.full_path}.git"
          ]

          result = instance.geo_custom_ssh_action

          expect(result).to be_a(Gitlab::GitAccessResult::CustomAction)
          expect(result.payload).to include(expected_payload)
          expect(result.console_messages).to eq(expected_console_messages)
        end
      end

      context 'when the actor is a user' do
        let(:instance) { test_class.new(user, project, 'ssh', cmd) }

        before do
          allow(instance).to receive_messages(
            custom_action_api_endpoints_for: [
              '/api/v4/geo/proxy_git_ssh/info_refs_receive_pack',
              '/api/v4/geo/proxy_git_ssh/receive_pack'
            ],
            primary_http_repo_internal_url: "http://primary.gitlab.com/#{project.full_path}.git",
            primary_ssh_url_to_repo: "git@primary.gitlab.com:#{project.full_path}.git",
            proxy_direct_to_primary_headers: { 'Authorization' => 'Bearer token' }
          )
        end

        it 'returns a custom action' do
          expected_payload = {
            "action" => "geo_proxy_to_primary",
            "data" => {
              "api_endpoints" => [
                "/api/v4/geo/proxy_git_ssh/info_refs_receive_pack",
                "/api/v4/geo/proxy_git_ssh/receive_pack"
              ],
              "primary_repo" => "http://primary.gitlab.com/#{project.full_path}.git",
              "geo_proxy_fetch_ssh_direct_to_primary" => true,
              "geo_proxy_push_ssh_direct_to_primary" => true,
              "request_headers" => include('Authorization')
            }
          }
          expected_console_messages = [
            "This request to a Geo secondary node will be forwarded to the",
            "Geo primary node:",
            "",
            "  git@primary.gitlab.com:#{project.full_path}.git"
          ]

          result = instance.geo_custom_ssh_action

          expect(result).to be_a(Gitlab::GitAccessResult::CustomAction)
          expect(result.payload).to include(expected_payload)
          expect(result.console_messages).to eq(expected_console_messages)
        end
      end
    end
  end
end
