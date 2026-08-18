# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectUserJwt, feature_category: :secrets_management do
  let_it_be(:grandparent_group) { create(:group) }
  let_it_be(:parent_group) { create(:group, parent: grandparent_group) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  subject(:jwt) { described_class.new(current_user: user, project: project) }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_s)
  end

  describe '#payload', :freeze_time do
    let(:payload) { jwt.payload }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('test-uuid')
      allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('test-correlation-id')
    end

    before_all do
      group.add_developer(user)
    end

    it 'includes user-specific claims' do
      expect(payload).to include(
        sub: "user:#{user.username}",
        aud: SecretsManagement::ProjectSecretsManager.jwt_audience,
        secrets_manager_scope: 'user'
      )
    end

    it 'includes role_id' do
      expect(payload[:role_id]).to eq(user.max_member_access_for_project(project.id).to_s)
    end

    it 'includes group_ids' do
      expect(payload[:groups]).to be_an(Array)
    end

    describe 'role_id with inherited access' do
      context 'when parent group has higher access level than project group' do
        before_all do
          grandparent_group.add_owner(user)
        end

        after(:all) do
          grandparent_group.members.find_by(user_id: user.id).destroy!
        end

        it 'includes the highest access level from the hierarchy' do
          expect(payload[:role_id]).to eq(Gitlab::Access::OWNER.to_s)
        end
      end

      context 'when user only has membership in an ancestor group' do
        let_it_be(:other_group) { create(:group, parent: grandparent_group) }
        let_it_be(:other_project) { create(:project, group: other_group) }

        subject(:jwt) { described_class.new(current_user: user, project: other_project) }

        before_all do
          grandparent_group.add_owner(user)
        end

        after(:all) do
          grandparent_group.members.find_by(user_id: user.id).destroy!
        end

        it 'includes the access level inherited from ancestor group' do
          expect(payload[:role_id]).to eq(Gitlab::Access::OWNER.to_s)
        end
      end
    end

    describe 'member_role_id' do
      context 'when project has no group' do
        let_it_be(:personal_project) { create(:project) }

        subject(:jwt) { described_class.new(current_user: user, project: personal_project) }

        it 'returns nil' do
          expect(payload[:member_role_id]).to be_nil
        end
      end

      context 'when user is not a direct member of the project group' do
        let_it_be(:other_group) { create(:group, parent: grandparent_group) }
        let_it_be(:other_project) { create(:project, group: other_group) }

        subject(:jwt) { described_class.new(current_user: user, project: other_project) }

        it 'returns nil' do
          expect(payload[:member_role_id]).to be_nil
        end
      end

      context 'when user is a direct member of the project group with a custom role' do
        let_it_be(:member_role) { create(:member_role, :developer, namespace: grandparent_group) }

        before_all do
          user.members.find_by(source: group).update!(member_role: member_role)
        end

        after(:all) do
          user.members.find_by(source: group).update!(member_role: nil)
        end

        it 'returns the member_role id' do
          expect(payload[:member_role_id]).to eq(member_role.id.to_s)
        end
      end

      context 'when user is a direct member of the project group without a custom role' do
        it 'checks ancestor groups for member roles' do
          expect(payload[:member_role_id]).to be_nil
        end
      end

      context 'when user has a custom role in an ancestor group' do
        let_it_be(:ancestor_member_role) { create(:member_role, :developer, namespace: grandparent_group) }

        before_all do
          grandparent_group.add_developer(user)
        end

        before_all do
          user.members.find_by(source: grandparent_group).update!(member_role: ancestor_member_role)
        end

        after(:all) do
          user.members.find_by(source: grandparent_group).update!(member_role: nil)
        end

        it 'returns the ancestor member_role id' do
          expect(payload[:member_role_id]).to eq(ancestor_member_role.id.to_s)
        end
      end

      context 'when user has no custom role in any ancestor group' do
        it 'returns nil' do
          expect(payload[:member_role_id]).to be_nil
        end
      end
    end
  end
end
