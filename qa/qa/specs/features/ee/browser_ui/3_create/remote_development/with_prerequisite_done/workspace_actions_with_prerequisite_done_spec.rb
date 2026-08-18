# frozen_string_literal: true

#   What does this test do
#
#   This is an e2e test that does not manage / orchestrate KAS / agentk / gitlab but expects them to be up and running.
#   This test is currently quarantined and is used for local testing only. This can be removed in the future when we
#   have a better approach for local testing. It can also be executed against an arbitrary environment with the
#   necessary pre-requisites completed.
#
#   How to setup the test:
#
#   1. Follow this documentation to set up your local GDK environment for creating remote development workspaces:
#      https://gitlab.com/gitlab-org/remote-development/gitlab-remote-development-docs/-/blob/main/doc/local-development-environment-setup.md
#   2. Ensure that a group exists with a project (default name: `devfile-project` or use DEVFILE_PROJECT to overwrite)
#   3. Ensure that an agent exists for the project (default name: `remotedev` or use AGENT_NAME to overwrite)
#   4. Ensure that the agent is enabled by clicking `Allow` from the Workspaces group settings
#   6. Ensure that you can successfully create and terminate workspaces
#   7. Run the script `scripts/remote_development/run-e2e-tests.sh`
#
#   Note 1: Default values can be overridden from the command line, for example:
#   DEVFILE_PROJECT="devfile-test-project" AGENT_NAME="test-agent" scripts/remote_development/run-e2e-tests.sh
#
#   Note 2: You can significantly speed up the test by providing a token with admin API access, which allows the test to
#   use the API to create a token, rather than the browser:
#   GITLAB_QA_ADMIN_ACCESS_TOKEN=abcde12345 scripts/remote_development/run-e2e-tests.sh

module QA
  RSpec.describe 'Create', feature_category: :workspaces,
    quarantine: {
      type: :waiting_on,
      issue: 'https://gitlab.com/gitlab-org/quality/test-failure-issues/-/issues/24051'
    } do
    describe 'Remote Development' do
      context 'when prerequisite is already done' do
        let!(:kubernetes_agent) do
          Resource::Clusters::Agent.init do |agent|
            agent.name = ENV['AGENT_NAME'] || "remotedev"
          end
        end

        let!(:devfile_project) do
          build(:project, add_name_uuid: false, name: ENV['DEVFILE_PROJECT'] || "devfile-project")
        end

        before do
          Flow::Login.sign_in
        end

        it_behaves_like 'workspaces actions'
      end
    end
  end
end
