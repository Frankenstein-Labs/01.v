# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::ScimAccessTokens::ResetService, :aggregate_failures, feature_category: :system_access do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group) }
  let_it_be(:admin) { create(:admin) }

  shared_examples 'a SCIM token reset service' do
    describe '#execute' do
      subject(:service) { described_class.new(current_user: admin, token: scim_token, audit_source: :api_admin_token) }

      it 'rotates the token' do
        expect { service.execute }.to change { scim_token.reload.token }
      end

      it 'returns success response' do
        expect(service.execute).to be_success
      end

      it 'logs the rotation event' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            Labkit::Fields::CLASS_NAME => described_class.name,
            message: "SCIM token rotated",
            source: :api_admin_token,
            reset_by: admin.username,
            token_id: scim_token.id
          )
        )

        service.execute
      end

      context 'when current_user is nil' do
        subject(:service) { described_class.new(current_user: nil, token: scim_token, audit_source: :api_admin_token) }

        it 'logs the rotation event with nil reset_by' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(reset_by: nil)
          )

          service.execute
        end
      end

      context 'when source is invalid' do
        subject(:service) { described_class.new(current_user: admin, token: scim_token, audit_source: :invalid_source) }

        it 'raises ArgumentError' do
          expect { service }.to raise_error(ArgumentError)
        end
      end
    end
  end

  context 'with ScimOauthAccessToken' do
    let(:scim_token) { create(:scim_oauth_access_token, organization: organization) }

    it_behaves_like 'a SCIM token reset service'
  end

  context 'with GroupScimAuthAccessToken' do
    let(:scim_token) { create(:group_scim_auth_access_token, group: group) }

    it_behaves_like 'a SCIM token reset service'
  end
end
