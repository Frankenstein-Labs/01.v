# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EnterpriseUsers::DisassociateService, :saas, feature_category: :user_management do
  subject(:service) { described_class.new(user: user) }

  let(:user_personal_access_token1) do
    create(:personal_access_token, user: user, group_id: user.enterprise_group_id)
  end

  let(:user_personal_access_token2) do
    create(:personal_access_token, :expired, user: user)
  end

  let(:user_personal_access_token3) do
    create(:personal_access_token, :revoked, user: user)
  end

  let(:another_user_personal_access_token) do
    create(:personal_access_token, group_id: create(:group).id)
  end

  describe '#execute' do
    shared_examples 'disassociates the user from the enterprise group' do
      it 'returns a successful response', :aggregate_failures do
        response = service.execute

        expect(response.success?).to eq(true)
        expect(response.payload[:group]).to eq(group)
        expect(response.payload[:user]).to eq(user)
      end

      it 'sets user.user_detail.enterprise_group_id from group.id to nil' do
        expect(user.user_detail.enterprise_group_id).to eq(group.id)

        service.execute

        user.reload

        expect(user.user_detail.enterprise_group_id).to eq(nil)
      end

      it 'sets user.user_detail.enterprise_group_associated_at to nil' do
        expect(user.user_detail.enterprise_group_associated_at).not_to eq(nil)

        service.execute

        user.reload

        expect(user.user_detail.enterprise_group_associated_at).to eq(nil)
      end

      it 'sets group_id for user.personal_access_tokens to nil', :aggregate_failures do
        previous_enterprise_group_id = user.user_detail.enterprise_group_id
        expect(previous_enterprise_group_id).not_to be_nil

        expect(user_personal_access_token1.group_id).to eq(previous_enterprise_group_id)
        expect(user_personal_access_token2.group_id).to eq(previous_enterprise_group_id)
        expect(user_personal_access_token3.group_id).to eq(previous_enterprise_group_id)

        expect(another_user_personal_access_token.group_id).not_to be_nil

        service.execute

        expect(user_personal_access_token1.reload.group_id).to be_nil
        expect(user_personal_access_token2.reload.group_id).to be_nil
        expect(user_personal_access_token3.reload.group_id).to be_nil

        expect(another_user_personal_access_token.reload.group_id).not_to be_nil
      end

      it 'logs message with info level about disassociating the user from the enterprise group' do
        allow(Gitlab::AppLogger).to receive(:info)

        expect(Gitlab::AppLogger).to receive(:info).with(
          class: service.class.name,
          group_id: group.id,
          user_id: user.id,
          message: 'Disassociated the user from the enterprise group'
        )

        service.execute
      end

      context 'when the user detail update fails' do
        before do
          user.user_detail.pronouns = 'x' * 51
        end

        it 'raises active record error' do
          expect(Gitlab::AppLogger).not_to receive(:info)

          expect { service.execute }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end

    shared_examples 'does not disassociate the user from the enterprise group' do |error_message, reason = nil|
      it 'returns a failed response', :aggregate_failures do
        response = service.execute

        expect(response.error?).to eq(true)
        expect(response.message).to eq(error_message)
        expect(response.reason).to eq(reason)
        expect(response.payload[:group]).to eq(group)
        expect(response.payload[:user]).to eq(user)
      end

      it 'does not update user.user_detail.enterprise_group_id' do
        previous_enterprise_group_id = user.user_detail.enterprise_group_id

        service.execute

        user.reload

        expect(user.user_detail.enterprise_group_id).to eq(previous_enterprise_group_id)
      end

      it 'does not update user.user_detail.enterprise_group_associated_at', :freeze_time do
        previous_enterprise_group_associated_at = user.user_detail.enterprise_group_associated_at

        service.execute

        user.reload

        expect(user.user_detail.enterprise_group_associated_at).to eq(previous_enterprise_group_associated_at)
      end

      it 'does not update group_id for user.personal_access_tokens to nil', :aggregate_failures do
        previous_enterprise_group_id = user.user_detail.enterprise_group_id

        expect(user_personal_access_token1.group_id).to eq(previous_enterprise_group_id)
        expect(user_personal_access_token2.group_id).to eq(previous_enterprise_group_id)
        expect(user_personal_access_token3.group_id).to eq(previous_enterprise_group_id)

        expect(another_user_personal_access_token.group_id).not_to be_nil

        service.execute

        expect(user_personal_access_token1.reload.group_id).to eq(previous_enterprise_group_id)
        expect(user_personal_access_token2.reload.group_id).to eq(previous_enterprise_group_id)
        expect(user_personal_access_token3.reload.group_id).to eq(previous_enterprise_group_id)

        expect(another_user_personal_access_token.reload.group_id).not_to be_nil
      end

      it 'does not log any message with info level' do
        expect(Gitlab::AppLogger).not_to receive(:info).with(
          message: 'Disassociated the user from the enterprise group'
        )

        service.execute
      end
    end

    context 'when the user is not an enterprise user' do
      let(:user) { create(:user) }
      let(:group) { nil }

      include_examples(
        'does not disassociate the user from the enterprise group',
        'The user is not an enterprise user'
      )
    end

    context 'when the user is an enterprise user' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:verified_domain) { create(:pages_domain, project: project) }
      let_it_be(:unverified_domain) { create(:pages_domain, :unverified, project: project) }

      let(:user_email_with_verified_domain) do
        create(:user, email: "example@#{verified_domain.domain}")
      end

      let(:user_email_with_unverified_domain) do
        create(:user, email: "example@#{unverified_domain.domain}")
      end

      before do
        stub_licensed_features(domain_verification: true)

        user.user_detail.update!(enterprise_group_id: group.id, enterprise_group_associated_at: Time.current)
      end

      context 'when the user matches the "Enterprise User" definition for the group' do
        let(:user) { user_email_with_verified_domain }

        include_examples(
          'does not disassociate the user from the enterprise group',
          'The user matches the "Enterprise User" definition for the group'
        )
      end

      context 'when the user does not match the "Enterprise User" definition for the group' do
        let(:user) { user_email_with_unverified_domain }

        include_examples 'disassociates the user from the enterprise group'
      end
    end
  end
end
