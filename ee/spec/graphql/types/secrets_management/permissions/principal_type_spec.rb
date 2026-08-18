# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Principal'], feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:users) { create_list(:user, 3) }
  let_it_be(:groups) { create_list(:group, 2) }

  # Test the fields are defined correctly with proper camelCase names
  it { expect(described_class).to have_graphql_fields(:id, :type, :user, :userRoleId, :group) }

  # Test field types
  describe 'field types' do
    it 'has ID type for id field' do
      expect(described_class.fields['id'].type.unwrap).to eq(GraphQL::Types::ID)
    end

    it 'has correct type for user field' do
      expect(described_class.fields['user'].type.unwrap.name).to eq('Types::UserType')
    end

    it 'has correct type for group field' do
      expect(described_class.fields['group'].type.unwrap.name).to eq('Types::GroupType')
    end
  end

  # Test field nullability
  describe 'field nullability' do
    it 'has non-nullable id and type fields' do
      expect(described_class.fields['id'].type.non_null?).to be_truthy
      expect(described_class.fields['type'].type.non_null?).to be_truthy
    end

    it 'has nullable user, userRoleId and group fields' do
      expect(described_class.fields['user'].type.non_null?).to be_falsey
      expect(described_class.fields['userRoleId'].type.non_null?).to be_falsey
      expect(described_class.fields['group'].type.non_null?).to be_falsey
    end
  end

  # Test field descriptions
  describe 'field descriptions' do
    it 'has correct description for user field' do
      expect(described_class.fields['user'].description).to include('User who is provided access to')
    end

    it 'has correct description for group field' do
      expect(described_class.fields['group'].description).to include('Group who is provided access to')
    end
  end

  describe 'batch loading' do
    it 'uses BatchModelLoader for user loading' do
      expect(Gitlab::Graphql::Loaders::BatchModelLoader).to receive(:new)
        .with(User, users.first.id.to_s)
        .and_call_original

      instance = Types::SecretsManagement::Permissions::PrincipalType.allocate
      object = { 'id' => users.first.id.to_s, 'type' => 'User' }
      instance.instance_variable_set(:@object, object)

      instance.send(:user_record)
    end

    it 'batches user loading to avoid N+1 queries' do
      principal1 = Types::SecretsManagement::Permissions::PrincipalType.allocate
      principal1.instance_variable_set(:@object, { 'id' => users.first.id.to_s, 'type' => 'User' })

      principal2 = Types::SecretsManagement::Permissions::PrincipalType.allocate
      principal2.instance_variable_set(:@object, { 'id' => users.second.id.to_s, 'type' => 'User' })

      # Test that we only make one query for both users
      expect do
        # Request both users but don't force loading yet
        user1_promise = principal1.send(:user_record)
        user2_promise = principal2.send(:user_record)

        # Force loading of both users
        user1_promise.sync
        user2_promise.sync
      end.not_to exceed_query_limit(1)
    end
  end
end
