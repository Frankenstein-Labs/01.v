# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PendingGroupMember'], feature_category: :user_management do
  it { expect(described_class.graphql_name).to eq('PendingGroupMember') }

  it { expect(described_class).to require_graphql_authorizations(:admin_group_member) }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(:name, :username, :email, :web_url, :avatar_url, :approved,
      :invited).at_least
  end
end
