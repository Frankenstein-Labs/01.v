# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Members::AdminRolesResolver, feature_category: :api do
  include GraphqlHelpers

  describe '#resolve' do
    subject(:result) do
      resolve(described_class, ctx: { current_user: admin }, arg_style: :internal)
    end

    let_it_be(:admin_role) { create(:member_role, :admin, :read_admin_cicd) }
    let_it_be(:custom_role) { create(:member_role, :read_code) }

    let_it_be(:admin) { create(:admin) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'returns admin roles', :enable_admin_mode do
      expect(result).to contain_exactly(admin_role)
    end
  end
end
