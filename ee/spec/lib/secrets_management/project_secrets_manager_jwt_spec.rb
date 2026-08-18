# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagerJwt, feature_category: :secrets_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { user }
  let(:current_project) { project }
  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  subject(:jwt) { described_class.new(current_user: current_user, project: current_project) }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_s)
  end

  describe '#initialize' do
    it 'sets current_user and project' do
      expect(jwt.current_user).to eq(user)
      expect(jwt.project).to eq(project)
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
        correlation_id: 'test-correlation-id'
      )
    end

    context 'with different user configurations' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when both project and user are present' do
        it 'includes all project and user claims' do
          expect(payload).to include(
            namespace_id: project.namespace_id.to_s,
            namespace_path: project.namespace.full_path,
            project_id: project.id.to_s,
            project_path: project.full_path,
            user_id: user.id.to_s,
            user_login: user.username,
            user_email: user.email
          )

          expect(payload[:user_access_level]).to eq('maintainer')
        end
      end

      context 'when user is not present' do
        let(:current_user) { nil }

        it 'includes project claims with nil user fields' do
          expect(payload).to include(
            namespace_id: project.namespace_id.to_s,
            namespace_path: project.namespace.full_path,
            project_id: project.id.to_s,
            project_path: project.full_path,
            user_id: "",
            user_login: nil,
            user_email: nil,
            user_access_level: nil
          )
        end
      end

      context 'when user has no project access' do
        let_it_be(:other_user) { create(:user) }
        let(:current_user) { other_user }

        it 'includes project claims with user info but nil access level' do
          expect(payload).to include(
            namespace_id: project.namespace_id.to_s,
            namespace_path: project.namespace.full_path,
            project_id: project.id.to_s,
            project_path: project.full_path,
            user_id: other_user.id.to_s,
            user_login: other_user.username,
            user_email: other_user.email,
            user_access_level: nil
          )
        end
      end
    end
  end

  describe '#encoded' do
    it 'returns an encoded JWT string' do
      encoded_token = jwt.encoded

      expect(encoded_token.split('.').size).to eq(3)
    end

    it 'can be decoded with the correct key' do
      encoded_token = jwt.encoded

      decoded_token = JWT.decode(encoded_token, rsa_key.public_key, true, { algorithm: 'RS256' })

      expect(decoded_token.first).to include('iss', 'iat', 'nbf', 'exp', 'jti', 'aud', 'sub')
    end
  end
end
