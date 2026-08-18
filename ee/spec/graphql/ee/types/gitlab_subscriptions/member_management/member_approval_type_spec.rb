# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['MemberApproval'], feature_category: :seat_cost_management do
  let(:fields) { described_class.fields }

  it 'has the correct graphql_name' do
    expect(described_class.graphql_name).to eq('MemberApproval')
  end

  it 'has a description' do
    expect(described_class.description).to eq('Represents a Member Approval queued for role promotion.')
  end

  it 'uses the CountableConnectionType' do
    expect(described_class.connection_type_class).to eq(::Types::CountableConnectionType)
  end

  describe 'fields' do
    it 'includes the specific fields' do
      expected_fields = %w[
        user
        newAccessLevel
        oldAccessLevel
        requestedBy
        reviewedBy
        status
        createdAt
        updatedAt
        memberRoleId
        member
      ]

      expect(described_class).to include_graphql_fields(*expected_fields)
    end

    it 'has a new_access_level field' do
      expect(fields['newAccessLevel']).to have_graphql_type(::Types::AccessLevelType)
    end

    it 'has a user field' do
      expect(fields['user']).to have_graphql_type(::Types::UserType)
    end

    it 'has an old_access_level field' do
      expect(fields['oldAccessLevel']).to have_graphql_type(::Types::AccessLevelType)
    end

    it 'has a requested_by field' do
      expect(fields['requestedBy']).to have_graphql_type(::Types::UserType)
    end

    it 'has a reviewed_by field' do
      expect(fields['reviewedBy']).to have_graphql_type(::Types::UserType)
    end

    it 'has a status field' do
      expect(fields['status']).to have_graphql_type(GraphQL::Types::String)
    end

    it 'has a created_at field' do
      expect(fields['createdAt']).to have_graphql_type(::Types::TimeType)
    end

    it 'has an updated_at field' do
      expect(fields['updatedAt']).to have_graphql_type(::Types::TimeType)
    end

    it 'has a member_role_id field' do
      expect(fields['memberRoleId']).to have_graphql_type(::GraphQL::Types::ID)
    end

    it 'has a member field' do
      expect(fields['member']).to have_graphql_type(::Types::MemberInterface)
    end
  end
end
