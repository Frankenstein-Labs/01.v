# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspacesAgentConfigPolicy, feature_category: :workspaces do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_refind(:agent_project_creator) { create(:user) }
  let_it_be_with_refind(:agent_project) { create(:project, creator: agent_project_creator) }
  let_it_be_with_refind(:agent) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: agent_project)
  end

  let_it_be(:agent_config) { agent.unversioned_latest_workspaces_agent_config }

  let_it_be_with_refind(:admin_user) { create(:admin) }
  let_it_be_with_refind(:non_admin_user) { create(:user) }
  # NOTE: The following need to be `let`, not `let_it_be`, because it uses a `let` declaration from the matrix
  let(:user) { admin_mode ? admin_user : non_admin_user }

  let(:policy_class) { described_class }

  subject(:policy_instance) { described_class.new(user, agent_config) }

  before do
    enable_admin_mode!(user) if admin_mode
    agent_project.add_role(user, role_on_agent_project) unless role_on_agent_project == :none
    agent_project.reload

    debug = false # Set to true to enable debugging of policies, but change back to false before committing
    # noinspection RubyMismatchedArgumentType -- We are passing a QA::Resource::User test double
    debug_policies(user, agent_config, policy_class, ability) if debug
  end

  shared_examples 'fixture sanity checks' do
    it "has fixture sanity checks" do
      # noinspection RubyMismatchedArgumentType,RubyResolve -- We are passing a test double
      expect(agent_project.creator_id).not_to eq(user.id)
    end
  end

  # rubocop:disable Layout/LineLength -- TableSyntax should not be split across lines
  where(:admin, :admin_mode, :role_on_agent_project, :allowed) do
    # @formatter:off - Turn off RubyMine autoformatting

    # admin      | # admin_mode | role_on_agent_project | allowed  # check
    true         | true         | :none                 | true     # admin with admin_mode enabled: allowed
    true         | false        | :none                 | false    # admin but admin_mode not enabled: not allowed
    false        | false        | :guest                | false    # non-admin guest on cluster agent project: not allowed
    false        | false        | :planner              | false    # non-admin planner on cluster agent project: not allowed
    false        | false        | :reporter             | false    # non-admin planner on cluster agent project: not allowed
    false        | false        | :developer            | true     # non-admin developer on cluster agent project: allowed
    false        | false        | :maintainer           | true     # non-admin maintainer on cluster agent project : allowed

    # @formatter:on
  end
  # rubocop:enable Layout/LineLength

  with_them do
    describe "read_workspaces_agent_config ability" do
      let(:ability) { :read_workspaces_agent_config }

      it_behaves_like 'fixture sanity checks'

      it { is_expected.to(allowed ? be_allowed(ability) : be_disallowed(ability)) }
    end
  end

  # NOTE: Leaving this method here for future use. You can also set GITLAB_DEBUG_POLICIES=1. For more details, see:
  #       https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities
  # This may be generalized in the future for use across all policy specs
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/463453
  #
  # @param [User] user
  # @param [RemoteDevelopment::WorkspacesAgentConfig] agent_config
  # @param [Class] policy_class
  # @param [Symbol] ability
  # @return [void]
  def debug_policies(user, agent_config, policy_class, ability)
    puts "\n\nPolicy debug for #{policy_class} policy:\n"
    puts "user: #{user.username} (id: #{user.id}, admin: #{user.admin?}, " \
      "admin_mode: #{user && Gitlab::Auth::CurrentUserMode.new(user).admin_mode?}" \
      ")\n"

    policy = policy_class.new(user, agent_config)
    puts "debugging :#{ability} ability:\n\n"
    pp policy.debug(ability)
    puts "\n\n"
  end
end
