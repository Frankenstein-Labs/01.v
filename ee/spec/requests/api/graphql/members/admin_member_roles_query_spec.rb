# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query admin member roles', feature_category: :permissions do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:admin) }
  let_it_be(:member_role) { create(:member_role, :admin, name: 'Admin role') }
  let(:fields) { 'nodes { usersCount }' }
  let(:query) { graphql_query_for('admin_member_roles', {}, fields) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_admin_member_role do
    let(:user) { current_user }
    let(:boundary_object) { :instance }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end
end
