# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe Clusters::AgentPolicy, feature_category: :workspaces do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be_with_reload(:agent) { create(:ee_cluster_agent) }
  let_it_be_with_reload(:project) { agent.project }
  let_it_be(:admin_in_non_admin_mode) { create(:admin) }
  let_it_be(:admin_in_admin_mode) { create(:admin) }
  let_it_be(:owner) { create(:user, owner_of: [project]) }
  let_it_be(:maintainer) { create(:user, maintainer_of: [project]) }
  let_it_be(:developer) { create(:user, developer_of: [project]) }
  let_it_be(:reporter) { create(:user, reporter_of: [project]) }
  let_it_be(:guest) { create(:user, guest_of: [project]) }

  describe ':admin_namespace_cluster_agent_mapping' do
    let(:ability) { :admin_namespace_cluster_agent_mapping }

    where(:user, :result) do
      ref(:guest)                   | false
      ref(:reporter)                | false
      ref(:developer)               | false
      ref(:maintainer)              | false
      ref(:owner)                   | true
      ref(:admin_in_non_admin_mode) | false
      ref(:admin_in_admin_mode)     | true
    end

    with_them do
      subject(:policy_instance) { Clusters::AgentPolicy.new(user, agent) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        # noinspection RubyMismatchedArgumentType -- RubyMine not properly detecting that this is a Class type
        debug_policies(user, agent, Clusters::AgentPolicy, ability) if debug
      end

      it { expect(policy_instance.allowed?(ability)).to eq(result) }
    end
  end

  describe ':admin_organization_cluster_agent_mapping' do
    let(:ability) { :admin_organization_cluster_agent_mapping }
    let_it_be(:organization_owner) { create(:user, owner_of: project.organization) }

    where(:user, :result) do
      ref(:guest)                   | false
      ref(:reporter)                | false
      ref(:developer)               | false
      ref(:maintainer)              | false
      ref(:owner)                   | true
      ref(:admin_in_non_admin_mode) | false
      ref(:admin_in_admin_mode)     | true
      ref(:organization_owner)      | true
    end

    with_them do
      subject(:policy_instance) { Clusters::AgentPolicy.new(user, agent) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        # noinspection RubyMismatchedArgumentType -- RubyMine not properly detecting that this is a Class type
        debug_policies(user, agent, Clusters::AgentPolicy, ability) if debug
      end

      it { expect(policy_instance.allowed?(ability)).to eq(result) }
    end
  end

  describe ':read_namespace_cluster_agent_mapping' do
    let(:ability) { :read_namespace_cluster_agent_mapping }

    where(:user, :result) do
      ref(:guest)                   | false
      ref(:reporter)                | false
      ref(:developer)               | false
      ref(:maintainer)              | true
      ref(:owner)                   | true
      ref(:admin_in_non_admin_mode) | false
      ref(:admin_in_admin_mode)     | true
    end

    with_them do
      subject(:policy_instance) { Clusters::AgentPolicy.new(user, agent) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode

        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        # noinspection RubyMismatchedArgumentType -- RubyMine not properly detecting that this is a Class type
        debug_policies(user, agent, Clusters::AgentPolicy, ability) if debug
      end

      it { expect(policy_instance.allowed?(ability)).to eq(result) }
    end
  end

  describe ":read_cluster_agent and :create_workspace" do
    RSpec.shared_examples "organization_workspaces_authorized_agent policy enforcement" do |ability|
      let_it_be(:project) { create(:project) }
      let_it_be(:organization) { project.organization }
      let_it_be(:user) { create(:user, organizations: []) }

      let_it_be(:agent_with_no_remote_development_config) do
        create(:ee_cluster_agent, project: project, name: "agent-with-no-workspace-config")
      end

      let_it_be(:agent_remote_dev_disabled) do
        create(:ee_cluster_agent, project: project, name: "agent-with-remote-dev-disabled").tap do |agent|
          create(:workspaces_agent_config, agent: agent, enabled: false)
          create(:organization_cluster_agent_mapping, user: user, agent: agent, organization: organization)
        end
      end

      let_it_be(:unmapped_agent_in_org) do
        create(:ee_cluster_agent, project: project, name: "agent-in-org-unmapped").tap do |agent|
          create(:workspaces_agent_config, agent: agent)
        end
      end

      let_it_be(:mapped_agent_in_unrelated_org) do
        create(:ee_cluster_agent, project: project, name: "agent-in-unrelated-org-mapped").tap do |agent|
          create(:workspaces_agent_config, agent: agent)
          create(:organization_cluster_agent_mapping, user: user, agent: agent, organization: create(:organization))
        end
      end

      let_it_be(:mapped_agent_in_org) do
        create(:ee_cluster_agent, project: project, name: "agent-in-org-mapped").tap do |agent|
          create(:workspaces_agent_config, agent: agent)
          create(:organization_cluster_agent_mapping, user: user, agent: agent, organization: organization)
        end
      end

      where(:agent, :user_in_org, :result) do
        ref(:mapped_agent_in_org)                       | true  | true
        ref(:mapped_agent_in_unrelated_org)             | true  | false
        ref(:agent_remote_dev_disabled)                 | true  | false
        ref(:unmapped_agent_in_org)                     | true  | false
        ref(:agent_with_no_remote_development_config)   | true  | false
        ref(:mapped_agent_in_org)                       | false | false
      end

      with_them do
        subject(:policy_instance) { Clusters::AgentPolicy.new(user, agent) }

        before do
          create(:organization_user, organization: organization, user: user) if user_in_org
          debug = false # Set to true to enable debugging of policies, but change back to false before committing
          # noinspection RubyMismatchedArgumentType -- RubyMine not properly detecting that this is a Class type
          debug_policies(user, agent, Clusters::AgentPolicy, ability) if debug
        end

        it "enforces the policy correctly" do
          expect(policy_instance.allowed?(ability)).to eq(result)
        end
      end
    end

    it_behaves_like "organization_workspaces_authorized_agent policy enforcement", :read_cluster_agent
    it_behaves_like "organization_workspaces_authorized_agent policy enforcement", :create_workspace
  end

  # NOTE: Leaving this method here for future use. You can also set GITLAB_DEBUG_POLICIES=1. For more details, see:
  #       https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities
  # This may be generalized in the future for use across all policy specs
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/463453
  #
  # @param [User] user
  # @param [Clusters::Agent] agent
  # @param [Class] policy_class
  # @param [Symbol] ability
  # @return [void]
  def debug_policies(user, agent, policy_class, ability)
    puts "\n\nPolicy debug for #{policy_class} policy:\n"
    puts "user: #{user.username} (id: #{user.id}, admin: #{user.admin?}, " \
      "admin_mode: #{user && Gitlab::Auth::CurrentUserMode.new(user).admin_mode?}, " \
      "agent.project.owners: #{agent.project.owners.to_a}, " \
      "agent.project.organization.organization_users.owners: " \
      "#{agent.project.organization.organization_users.owners.to_a}, " \
      "agent.project.maintainers: #{agent.project.maintainers.to_a}" \
      ")"

    policy = policy_class.new(user, agent)
    puts "debugging :#{ability} ability:\n\n"
    pp policy.debug(ability)
    puts "\n\n"
  end
end
