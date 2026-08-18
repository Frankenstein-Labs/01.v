# frozen_string_literal: true

# This test is currently disabled due to dependency on deprecated Workspaces staging secrets and high maintenance cost.

#   This is an e2e test that sets up the entire workspaces environment from scratch as mentioned in this documentation
#   https://gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/-/blob/main/doc/local-development-environment-setup.md
#   This test creates a project, devfile, agent and workspace. It enables the agent via the Workspaces settings.
#   For local testing where the pre-requisites have already been met please use the following test:
#   `ee/browser_ui/3_create/remote_development/with_prerequisite_done/workspace_actions_with_prerequisite_done_spec.rb`
#
#   How to run the test locally against staging:
#   1. The following pre-requisites are required to be installed:
#     - gcloud CLI https://cloud.google.com/sdk/docs/install
#     - google-cloud-sdk-gke-gcloud-auth-plugin `gcloud components install gke-gcloud-auth-plugin`
#     - Helm https://helm.sh/docs/intro/install/
#
#   2. To run the test against staging environment, use the full list of environment variables which can be found in
#      1password under "Run workspaces tests against staging" and run:
#      bundle exec bin/qa Test::Instance::All https://staging.gitlab.com -- -- qa/specs/features/ee/browser_ui/3_create
#      /remote_development/workspace_actions_spec.rb

module QA
  RSpec.describe 'Create', only: { pipeline: %i[staging staging-canary] }, feature_category: :workspaces,
    quarantine: {
      issue: 'https://gitlab.com/gitlab-org/gitlab/-/work_items/595190',
      type: :stale
    } do
    describe 'Remote Development' do
      include Runtime::Fixtures

      context 'when prerequisite is done in runtime' do
        let!(:cluster) do
          if QA::Runtime::Env.workspaces_cluster_available?
            Service::KubernetesCluster.new(provider_class: Service::ClusterProvider::Gcloud).connect!
          else
            Service::KubernetesCluster.new(provider_class: Service::ClusterProvider::Gcloud).create!
          end
        end

        let(:parent_group) do
          create(:group, path: "parent-group-to-test-remote-development-#{SecureRandom.hex(8)}")
        end

        let(:agent_project) { create(:project, group: parent_group, name: 'agent-project') }
        let(:kubernetes_agent) do
          create(:cluster_agent, name: "remotedev-#{SecureRandom.hex(4)}", project: agent_project)
        end

        let!(:agent_token) { create(:cluster_agent_token, agent: kubernetes_agent) }

        let!(:agent_config_file) do
          agent_config_yaml = ERB.new(read_ee_fixture('remote_development', 'agent-config.yaml.erb')).result(binding)
          create(:commit, project: agent_project, commit_message: 'Add remote dev agent configuration', actions: [
            {
              action: 'create',
              file_path: ".gitlab/agents/#{kubernetes_agent.name}/config.yaml",
              content: agent_config_yaml
            }
          ])
        end

        let(:devfile_project) { create(:project, group: parent_group, name: 'devfile-project') }
        let!(:devfile_file) do
          devfile_yaml = ERB.new(read_ee_fixture('remote_development', 'devfile.yaml.erb')).result(binding)

          create(:commit, project: devfile_project, commit_message: 'Add .devfile.yaml', actions: [
            { action: 'create', file_path: '.devfile.yaml', content: devfile_yaml }
          ])
        end

        before do
          cluster.setup_workspaces_in_cluster unless QA::Runtime::Env.workspaces_cluster_available?
          cluster.install_kubernetes_agent(agent_token.token, kubernetes_agent.name)
          cluster.update_dns_with_load_balancer_ip
          Flow::Login.sign_in

          parent_group.visit!
          Page::Group::Menu.perform(&:go_to_workspaces_settings)
          EE::Page::Group::Settings::Workspaces.perform(&:allow_agent)
        end

        after do
          if QA::Runtime::Env.workspaces_cluster_available?
            cluster.uninstall_kubernetes_agent(kubernetes_agent.name)
          else
            cluster&.remove!
          end

          agent_token.remove_via_api!
          kubernetes_agent.remove_via_api!
          parent_group.remove_via_api!
        end

        it_behaves_like 'workspaces actions'
      end
    end
  end
end
