# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupUserJwt, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { user }
  let(:current_group) { group }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  subject(:jwt) { described_class.new(current_user: current_user, group: current_group) }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_s)
  end

  describe '#initialize' do
    it 'sets current_user and group' do
      expect(jwt.current_user).to eq(user)
      expect(jwt.group).to eq(group)
    end
  end

  describe '#payload', :freeze_time do
    let(:payload) { jwt.payload }
    let(:now) { Time.now.to_i }

    before do
      allow(SecureRandom).to receive(:uuid).and_return('test-uuid')
      allow(Labkit::Correlation::CorrelationId).to receive(:current_id).and_return('test-correlation-id')
    end

    it 'includes the standard JWT claims' do
      expect(payload).to include(
        iss: Gitlab.config.gitlab.url,
        iat: now,
        nbf: now,
        exp: now + described_class::DEFAULT_TTL.to_i,
        jti: 'test-uuid',
        aud: 'http://127.0.0.1:9800',
        sub: "user:#{user.username}",
        secrets_manager_scope: 'user',
        correlation_id: 'test-correlation-id'
      )
    end

    context 'with different user configurations' do
      context 'when both group and user are present' do
        before_all do
          group.add_owner(user)
        end

        it 'includes group and user claims' do
          expect(payload).to include(
            group_id: group.id.to_s,
            group_path: group.full_path,
            root_group_id: group.id.to_s,
            organization_id: group.organization.id.to_s,
            organization_path: group.organization.path,
            user_id: user.id.to_s,
            user_login: user.username,
            user_email: user.email
          )
        end

        it 'includes role_id claim' do
          expect(payload[:role_id]).to eq(Gitlab::Access::OWNER.to_s)
        end

        it 'includes groups claim with the group' do
          expect(payload[:groups]).to eq([group.id.to_s])
        end

        it 'does not include project claims' do
          expect(payload).not_to have_key(:project_id)
          expect(payload).not_to have_key(:project_path)
        end
      end

      context 'when user is not a member of the group' do
        let_it_be(:other_user) { create(:user) }
        let(:current_user) { other_user }

        it 'includes group and user claims' do
          expect(payload).to include(
            group_id: group.id.to_s,
            group_path: group.full_path,
            user_id: other_user.id.to_s,
            user_login: other_user.username,
            user_email: other_user.email
          )
        end

        it 'includes empty groups claim' do
          expect(payload[:groups]).to eq([])
        end

        it 'includes role_id as no access' do
          expect(payload[:role_id]).to eq(Gitlab::Access::NO_ACCESS.to_s)
        end
      end

      context 'when user has a member role in the group' do
        let_it_be(:member_role) { create(:member_role, namespace: group) }

        before_all do
          create(:group_member, :developer, source: group, user: user, member_role: member_role)
        end

        it 'includes member_role_id claim' do
          expect(payload[:member_role_id]).to eq(member_role.id.to_s)
        end
      end
    end

    context 'when group is not present' do
      let(:current_group) { nil }

      it 'raises an error' do
        expect { payload }.to raise_error(NoMethodError)
      end
    end

    context 'with nested group hierarchy' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group) }
      let(:current_group) { subgroup }

      before_all do
        parent_group.add_developer(user)
        subgroup.add_maintainer(user)
      end

      it 'includes the subgroup information' do
        expect(payload).to include(
          group_id: subgroup.id.to_s,
          group_path: subgroup.full_path
        )
      end

      it 'includes all relevant groups in hierarchy user is member of' do
        expect(payload[:groups]).to match_array([subgroup.id.to_s, parent_group.id.to_s])
      end

      it 'includes the highest access level in the hierarchy' do
        expect(payload[:role_id]).to eq(Gitlab::Access::MAINTAINER.to_s)
      end
    end

    context 'when parent group has higher access level than subgroup' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group) }
      let(:current_group) { subgroup }

      before_all do
        parent_group.add_owner(user)
        subgroup.add_developer(user)
      end

      it 'includes the highest access level from the hierarchy' do
        expect(payload[:role_id]).to eq(Gitlab::Access::OWNER.to_s)
      end
    end

    context 'when user only has membership in parent group' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group) }
      let(:current_group) { subgroup }

      before_all do
        parent_group.add_owner(user)
      end

      it 'includes the access level inherited from parent group' do
        # Verify user has no direct membership on the subgroup
        expect(user.max_member_access_for_group(subgroup.id)).to eq(Gitlab::Access::NO_ACCESS)

        expect(payload[:role_id]).to eq(Gitlab::Access::OWNER.to_s)
      end
    end

    context 'when access is granted through group sharing (GroupGroupLink)' do
      # Mirrors the dogfooding bug: the user's only membership lives in a
      # separate group tree, and access to the target subgroup is routed
      # entirely through an Owner-level share on the target's ancestor.
      let_it_be(:shared_parent) { create(:group) }
      let_it_be(:target_subgroup) { create(:group, parent: shared_parent) }
      let_it_be(:sharing_group) { create(:group) }

      let(:current_group) { target_subgroup }

      before_all do
        sharing_group.add_owner(user)
        create(:group_group_link, :owner, shared_group: shared_parent, shared_with_group: sharing_group)
      end

      it 'has no direct or inherited membership on the target hierarchy' do
        expect(user.max_member_access_for_group_ids(target_subgroup.self_and_ancestor_ids).values.max.to_i)
          .to eq(Gitlab::Access::NO_ACCESS)
      end

      it 'resolves role_id through the share to Owner, consistent with the groups claim', :aggregate_failures do
        # role_id and the groups claim are computed via separate code paths;
        # both must resolve the share so the JWT stays internally consistent.
        expect(payload[:role_id]).to eq(Gitlab::Access::OWNER.to_s)
        expect(payload[:groups]).to include(target_subgroup.id.to_s)
      end
    end

    context 'when user is an instance admin with no group membership' do
      let_it_be(:admin_user) { create(:user, :admin) }

      let(:current_user) { admin_user }

      it 'resolves role_id to NO_ACCESS, not implicitly granting Owner to admins', :aggregate_failures do
        # only_concrete_membership: true must prevent the admin bypass path
        expect(payload[:role_id]).to eq(Gitlab::Access::NO_ACCESS.to_s)
        expect(payload[:groups]).to eq([])
      end
    end

    context 'with member role in parent group' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group) }
      let_it_be(:member_role) { create(:member_role, namespace: parent_group) }
      let(:current_group) { subgroup }

      before_all do
        create(:group_member, :developer, source: parent_group, user: user, member_role: member_role)
      end

      it 'includes member_role_id from parent group' do
        expect(payload[:member_role_id]).to eq(member_role.id.to_s)
      end
    end
  end

  describe '#encoded' do
    before_all do
      group.add_owner(user)
    end

    it 'returns an encoded JWT string' do
      encoded_token = jwt.encoded

      expect(encoded_token.split('.').size).to eq(3) # Header, payload, signature
    end

    it 'can be decoded with the correct key' do
      encoded_token = jwt.encoded

      decoded_token = JWT.decode(encoded_token, rsa_key.public_key, true, { algorithm: 'RS256' })

      expect(decoded_token.first).to include('iss', 'iat', 'nbf', 'exp', 'jti', 'aud', 'sub')
    end

    it 'includes group-specific claims when decoded' do
      encoded_token = jwt.encoded

      decoded_token = JWT.decode(encoded_token, rsa_key.public_key, true, { algorithm: 'RS256' })
      claims = decoded_token.first

      expect(claims).to include(
        'group_id' => group.id.to_s,
        'group_path' => group.full_path,
        'user_id' => user.id.to_s,
        'secrets_manager_scope' => 'user'
      )
      expect(claims['groups']).to include(group.id.to_s)
      expect(claims).not_to have_key('project_id')
    end

    it 'has sub claim with user prefix' do
      encoded_token = jwt.encoded

      decoded_token = JWT.decode(encoded_token, rsa_key.public_key, true, { algorithm: 'RS256' })
      claims = decoded_token.first

      expect(claims['sub']).to eq("user:#{user.username}")
    end
  end
end
