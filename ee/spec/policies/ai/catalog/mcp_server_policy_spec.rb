# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServerPolicy, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: organization) }

  subject(:policy) { described_class.new(user, mcp_server) }

  describe 'delegation' do
    it { is_expected.to delegate_to(::Organizations::OrganizationPolicy) }
  end
end
