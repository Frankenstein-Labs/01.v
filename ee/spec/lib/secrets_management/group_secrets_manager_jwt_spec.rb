# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecretsManagerJwt, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { user }
  let(:current_group) { group }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  subject(:jwt) { described_class.new(current_user: current_user, group: current_group) }

  # Set up the signing key for all tests
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
        exp: now + SecretsManagement::GlobalSecretsManagerJwt::DEFAULT_TTL.to_i,
        jti: 'test-uuid',
        aud: 'http://127.0.0.1:9800',
        sub: 'gitlab_secrets_manager',
        secrets_manager_scope: 'privileged',
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

        it 'does not include project claims' do
          expect(payload).not_to have_key(:project_id)
          expect(payload).not_to have_key(:project_path)
        end
      end

      context 'when user is not present' do
        let(:current_user) { nil }

        it 'includes group claims with nil user fields' do
          expect(payload).to include(
            group_id: group.id.to_s,
            group_path: group.full_path
          )
          expect(payload[:user_id]).to eq("")
          expect(payload[:user_login]).to be_nil
          expect(payload[:user_email]).to be_nil
        end
      end

      context 'when user is not a member of the group' do
        let_it_be(:other_user) { create(:user) }
        let(:current_user) { other_user }

        it 'includes group claims with user info' do
          expect(payload).to include(
            group_id: group.id.to_s,
            group_path: group.full_path,
            user_id: other_user.id.to_s,
            user_login: other_user.username,
            user_email: other_user.email
          )
        end
      end
    end

    context 'when group is not present' do
      let(:current_group) { nil }

      it 'raises an error' do
        expect { payload }.to raise_error(NoMethodError)
      end
    end

    context 'with nested group' do
      let_it_be(:parent_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: parent_group) }

      before do
        group.parent = subgroup
        group.save!
      end

      it 'includes the root group id' do
        expect(payload).to include(
          group_id: group.id.to_s,
          root_group_id: parent_group.id.to_s
        )
      end
    end
  end

  describe '#encoded' do
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
        'user_id' => user.id.to_s
      )
      expect(claims).not_to have_key('project_id')
    end
  end
end
