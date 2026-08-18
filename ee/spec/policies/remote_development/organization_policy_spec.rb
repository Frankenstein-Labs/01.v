# frozen_string_literal: true

require 'spec_helper'

# noinspection RubyArgCount -- https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
RSpec.describe RemoteDevelopment::OrganizationPolicy, feature_category: :workspaces do
  include AdminModeHelper
  using RSpec::Parameterized::TableSyntax

  let_it_be(:organization) { create(:organization) }
  let_it_be(:non_org_user) { create(:user) }

  let_it_be(:organization_user) do
    user = create(:user)
    create(:organization_user, organization: organization, user: user)
    user
  end

  let_it_be(:organization_owner) { create(:user, owner_of: organization) }
  let_it_be(:admin_in_admin_mode) { create(:user, :admin) }
  let_it_be(:admin_not_in_admin_mode) { create(:user, :admin) }

  describe ':admin_organization_cluster_agent_mapping' do
    let(:ability) { :admin_organization_cluster_agent_mapping }

    where(:policy_class, :user, :result) do
      # In the future, there is a possibility that a common policy module may have to be mixed in to multiple
      # target policy types for ex. ProjectNamespacePolicy or UserNamespacePolicy. As a result, the policy_class
      # has been parameterized to accommodate different values that may exist in the future
      #
      # See the following issues for more details:
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/417894
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/454934#note_1867678918
      Organizations::OrganizationPolicy | ref(:organization_user)        | false
      Organizations::OrganizationPolicy | ref(:admin_not_in_admin_mode)  | false
      Organizations::OrganizationPolicy | ref(:non_org_user)             | false
      Organizations::OrganizationPolicy | ref(:admin_in_admin_mode)      | true
      Organizations::OrganizationPolicy | ref(:organization_owner)       | true
    end

    with_them do
      subject(:policy_instance) { policy_class.new(user, organization) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode
        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        debug_policies(user, organization, policy_class, ability) if debug
      end

      it { expect(policy_instance.allowed?(ability)).to eq(result) }
    end
  end

  describe ':read_organization_cluster_agent_mapping' do
    let(:ability) { :read_organization_cluster_agent_mapping }

    where(:policy_class, :user, :result) do
      # In the future, there is a possibility that a common policy module may have to be mixed in to multiple
      # target policy types for ex. ProjectNamespacePolicy or UserNamespacePolicy. As a result, the policy_class
      # has been parameterized to accommodate different values that may exist in the future
      #
      # See the following issues for more details:
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/417894
      #   - https://gitlab.com/gitlab-org/gitlab/-/issues/454934#note_1867678918
      Organizations::OrganizationPolicy | ref(:organization_user)        | true
      Organizations::OrganizationPolicy | ref(:organization_owner)       | true
      Organizations::OrganizationPolicy | ref(:admin_in_admin_mode)      | true
      Organizations::OrganizationPolicy | ref(:admin_not_in_admin_mode)  | false
      Organizations::OrganizationPolicy | ref(:non_org_user)             | false
    end

    with_them do
      subject(:policy_instance) { policy_class.new(user, organization) }

      before do
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode
        debug = false # Set to true to enable debugging of policies, but change back to false before committing
        debug_policies(user, organization, policy_class, ability) if debug
      end

      it { expect(policy_instance.allowed?(ability)).to eq(result) }
    end
  end

  # NOTE: Leaving this method here for future use. You can also set GITLAB_DEBUG_POLICIES=1. For more details, see:
  #       https://docs.gitlab.com/ee/development/permissions/custom_roles.html#refactoring-abilities
  # This may be generalized in the future for use across all policy specs
  # Issue: https://gitlab.com/gitlab-org/gitlab/-/issues/463453
  #
  # @param user [User] the user making the request.
  # @param org [Organizations::Organization] the organization that is the subject of the request.
  # @param policy_class [Organizations::OrganizationPolicy] the policy class.
  # @param ability [Symbol] the ability needed by the user to allow the request.
  # @return [nil] This method does not return any value.
  def debug_policies(user, org, policy_class, ability)
    org_user = user.organization_users.find { |org_user| org_user.organization.id == org.id }
    org_owners = Organizations::OrganizationUser.owners.filter { |owner| owner.organization_id == org.id }
    puts "\n\nPolicy debug for #{policy_class} policy:\n"
    puts "user: #{user.username} (id: #{user.id}, admin: #{user.admin?}, " \
      "admin_mode: #{user && Gitlab::Auth::CurrentUserMode.new(user).admin_mode?}" \
      ")\n"
    # noinspection RubyRedundantSafeNavigation -- Inspection bug in RubyMine, this safe navigation operator is needed
    puts "org: #{org.name} (id: #{org.id}, " \
      "owners: #{org_owners} " \
      "user access level in org: #{org_user&.access_level || 'not in org'}" \

    policy = policy_class.new(user, org)
    puts "debugging :#{ability} ability:\n\n"
    pp policy.debug(ability)
    puts "\n\n"
  end
end
