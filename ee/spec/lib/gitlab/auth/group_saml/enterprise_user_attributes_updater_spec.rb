# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::EnterpriseUserAttributesUpdater, feature_category: :user_management do
  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user, can_create_group: true, projects_limit: 10) }
    let_it_be(:group) { create(:group) }

    let(:raw_info_attributes) { { 'can_create_group' => %w[false], 'projects_limit' => %w[20] } }
    let(:auth_hash) do
      Gitlab::Auth::GroupSaml::AuthHash.new(
        OmniAuth::AuthHash.new(
          extra: { raw_info: OneLogin::RubySaml::Attributes.new(raw_info_attributes) }
        )
      )
    end

    subject(:execute) { described_class.new(user, group, auth_hash).execute }

    context 'when the user is managed by the group', :saas do
      before do
        stub_licensed_features(domain_verification: true)
        user.user_detail.update!(enterprise_group: group)
      end

      it 'updates the user attributes', :aggregate_failures do
        expect { execute }
          .to change { user.reload.can_create_group }.from(true).to(false)
          .and change { user.reload.projects_limit }.from(10).to(20)
      end

      it 'logs that the user attributes were updated' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          Labkit::Fields::CLASS_NAME => described_class.name,
          Labkit::Fields::GL_USER_ID => user.id,
          group_id: group.id,
          message: 'Updated the enterprise user attributes.'
        )

        execute
      end

      it 'returns result with success status' do
        result = execute

        expect(result).to include(status: :success)
      end

      context 'when the user attributes are invalid' do
        let(:raw_info_attributes) { { 'projects_limit' => %w[-1] } }

        it 'adds validation errors to the user', :aggregate_failures do
          execute

          expect(user.errors.messages).to eq({ projects_limit: ['must be greater than or equal to 0'] })
        end

        it 'logs that the user attributes update failed, with errors' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            Labkit::Fields::CLASS_NAME => described_class.name,
            Labkit::Fields::GL_USER_ID => user.id,
            group_id: group.id,
            message: 'Failed to update the enterprise user attributes. ' \
              'Projects limit must be greater than or equal to 0.'
          )

          execute
        end

        it 'returns result with error status and message' do
          result = execute

          expect(result).to include(status: :error, message: 'Projects limit must be greater than or equal to 0')
        end
      end

      context 'when the user attributes are not present in the SAML response' do
        let(:raw_info_attributes) { {} }

        it 'is no-op', :aggregate_failures do
          expect(Users::UpdateService).not_to receive(:new)
          expect(Gitlab::AppLogger).not_to receive(:info)

          expect(execute).to be_nil
        end
      end
    end

    context 'when the user is not managed by the group' do
      it 'is no-op', :aggregate_failures do
        expect(Users::UpdateService).not_to receive(:new)
        expect(Gitlab::AppLogger).not_to receive(:info)

        expect(execute).to be_nil
      end
    end
  end
end
