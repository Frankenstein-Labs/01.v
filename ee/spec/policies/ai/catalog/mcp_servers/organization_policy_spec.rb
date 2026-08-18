# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::OrganizationPolicy, feature_category: :workflow_catalog do
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

  describe ':read_ai_catalog_mcp_server' do
    where(:user, :mcp_servers_available, :result) do
      ref(:organization_user) | true | true
      ref(:organization_user) | false | false
      ref(:organization_owner) | true | true
      ref(:admin_in_admin_mode) | true | true
      ref(:admin_not_in_admin_mode) | true | false
      ref(:non_org_user) | true | false
    end

    with_them do
      subject(:policy_instance) { Organizations::OrganizationPolicy.new(user, organization) }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(mcp_servers_available)
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode
      end

      it { expect(policy_instance.allowed?(:read_ai_catalog_mcp_server)).to eq(result) }
    end
  end

  describe ':create_ai_catalog_mcp_server' do
    where(:user, :mcp_servers_available, :result) do
      ref(:organization_user) | true | false
      ref(:organization_user) | false | false
      ref(:organization_owner) | true | true
      ref(:admin_in_admin_mode) | true | true
      ref(:admin_not_in_admin_mode) | true | false
      ref(:non_org_user) | true | false
    end

    with_them do
      subject(:policy_instance) { Organizations::OrganizationPolicy.new(user, organization) }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(mcp_servers_available)
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode
      end

      it { expect(policy_instance.allowed?(:create_ai_catalog_mcp_server)).to eq(result) }
    end
  end

  describe ':update_ai_catalog_mcp_server' do
    where(:user, :mcp_servers_available, :result) do
      ref(:organization_user) | true | false
      ref(:organization_user) | false | false
      ref(:organization_owner) | true | true
      ref(:admin_in_admin_mode) | true | true
      ref(:admin_not_in_admin_mode) | true | false
      ref(:non_org_user) | true | false
    end

    with_them do
      subject(:policy_instance) { Organizations::OrganizationPolicy.new(user, organization) }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(mcp_servers_available)
        enable_admin_mode!(admin_in_admin_mode) if user == admin_in_admin_mode
      end

      it { expect(policy_instance.allowed?(:update_ai_catalog_mcp_server)).to eq(result) }
    end
  end
end
