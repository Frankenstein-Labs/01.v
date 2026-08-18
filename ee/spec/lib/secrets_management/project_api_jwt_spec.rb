# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectApiJwt, feature_category: :secrets_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, developers: user) }
  let_it_be(:project) { create(:project, group: group) }

  let(:rsa_key) { OpenSSL::PKey::RSA.generate(3072) }

  subject(:jwt) { described_class.new(current_user: user, project: project, auth_via: 'PAT') }

  before do
    stub_application_setting(ci_jwt_signing_key: rsa_key.to_s)
  end

  describe '#payload', :freeze_time do
    let(:payload) { jwt.payload }

    it 'uses the api scope and records the auth_via token type' do
      expect(payload).to include(
        sub: "user:#{user.username}",
        secrets_manager_scope: 'api',
        auth_via: 'PAT'
      )
    end

    it 'keeps the user claims needed for policy resolution' do
      expect(payload[:role_id]).to eq(user.max_member_access_for_project(project.id).to_s)
      expect(payload[:groups]).to be_an(Array)
    end

    it 'honors a custom ttl' do
      now = Time.now.to_i
      expect(described_class.new(current_user: user, project: project, auth_via: 'PAT', ttl: 5.minutes).payload[:exp])
        .to eq(now + 5.minutes.to_i)
    end
  end
end
