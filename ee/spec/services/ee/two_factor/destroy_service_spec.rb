# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TwoFactor::DestroyService, feature_category: :system_access do
  let_it_be(:current_user) { create(:user, :two_factor) }
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:user) { create(:user, :two_factor) }

  subject(:disable_2fa_with_group) { described_class.new(current_user, user: user, group: group).execute }

  describe 'disabling two-factor authentication with group', :saas do
    shared_examples 'does not disable two-factor authentication' do
      it 'returns error' do
        expect(disable_2fa_with_group).to eq(
          {
            status: :error,
            message: 'You are not authorized to perform this action'
          }
        )
      end

      it 'does not disable the two-factor authentication of the user' do
        expect { disable_2fa_with_group }.not_to change { user.reload.two_factor_enabled? }.from(true)
      end

      it 'does not create an audit event' do
        expect { disable_2fa_with_group }.not_to change { AuditEventReader.count }
      end
    end

    shared_examples 'disables two-factor authentication' do
      it 'returns success' do
        expect(disable_2fa_with_group).to include({ status: :success })
      end

      it 'disables the two-factor authentication of the user' do
        expect { disable_2fa_with_group }.to change { user.reload.two_factor_enabled? }.from(true).to(false)
      end

      it 'creates an audit event', :aggregate_failures do
        expect { disable_2fa_with_group }.to change { AuditEventReader.count }.by(1)

        expect(AuditEventReader.last).to have_attributes(
          author: current_user,
          entity_id: group.id,
          target_id: user.id,
          target_type: current_user.class.name,
          target_details: user.name,
          details: include(custom_message: 'Disabled two-factor authentication')
        )
      end
    end

    using RSpec::Parameterized::TableSyntax

    where(
      :domain_verification_availabe_for_group,
      :user_is_enterprise_user_of_the_group,
      :current_user_is_group_owner,
      :shared_examples
    ) do
      false | false  | false  | 'does not disable two-factor authentication'
      false | false  | true   | 'does not disable two-factor authentication'
      false | true   | false  | 'does not disable two-factor authentication'
      false | true   | true   | 'does not disable two-factor authentication'
      true  | false  | false  | 'does not disable two-factor authentication'
      true  | false  | true   | 'does not disable two-factor authentication'
      true  | true   | false  | 'does not disable two-factor authentication'
      true  | true   | true   | 'disables two-factor authentication'
    end

    with_them do
      before do
        stub_licensed_features(
          domain_verification: domain_verification_availabe_for_group,
          admin_audit_log: true,
          audit_events: true,
          extended_audit_events: true
        )

        user.user_detail.update!(enterprise_group_id: user_is_enterprise_user_of_the_group ? group.id : -42)

        if current_user_is_group_owner
          group.add_owner(current_user)
        else
          group.add_maintainer(current_user)
        end
      end

      include_examples params[:shared_examples]
    end
  end
end
