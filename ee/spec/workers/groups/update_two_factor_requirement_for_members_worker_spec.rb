# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::UpdateTwoFactorRequirementForMembersWorker, feature_category: :system_access do
  let(:worker) { described_class.new }

  before do
    stub_licensed_features(minimal_access_role: true)
  end

  describe '#perform' do
    context 'when the group no longer requires two-factor authentication' do
      let_it_be_with_reload(:group) { create(:group, require_two_factor_authentication: false) }
      let_it_be_with_reload(:minimal_access_user) { create(:user) }
      let_it_be_with_reload(:developer) { create(:user) }

      before_all do
        create(:group_member, :minimal_access, source: group, user: minimal_access_user)
        create(:group_member, :developer, source: group, user: developer)

        # A stale requirement cannot be produced through factories or callbacks,
        # since those recalculate the truthful value, so it is planted directly
        minimal_access_user.update!(require_two_factor_authentication_from_group: true, two_factor_grace_period: 23)
        developer.update!(require_two_factor_authentication_from_group: true, two_factor_grace_period: 23)
      end

      it 'recalculates the requirement for members with the Minimal Access role' do
        expect { worker.perform(group.id) }
          .to change { minimal_access_user.reload.require_two_factor_authentication_from_group }
          .from(true).to(false)
      end

      it 'recalculates the requirement for members with other roles' do
        expect { worker.perform(group.id) }
          .to change { developer.reload.require_two_factor_authentication_from_group }
          .from(true).to(false)
      end

      context 'when minimal_access_role is not available' do
        before do
          stub_licensed_features(minimal_access_role: false)
        end

        it 'still clears the stale requirement for members with the Minimal Access role' do
          expect { worker.perform(group.id) }
            .to change { minimal_access_user.reload.require_two_factor_authentication_from_group }
            .from(true).to(false)
        end
      end
    end

    context 'when the group requires two-factor authentication' do
      let_it_be_with_reload(:group) do
        create(:group, require_two_factor_authentication: true, two_factor_grace_period: 23)
      end

      let_it_be_with_reload(:minimal_access_user) { create(:user) }

      before_all do
        create(:group_member, :minimal_access, source: group, user: minimal_access_user)

        # The membership is created before the license stub applies, so the
        # starting value is planted explicitly rather than left to hook order
        minimal_access_user.update!(require_two_factor_authentication_from_group: false)
      end

      it 'enforces the requirement for members with the Minimal Access role' do
        expect { worker.perform(group.id) }
          .to change { minimal_access_user.reload.require_two_factor_authentication_from_group }
          .from(false).to(true)
      end
    end

    it 'does nothing when the group does not exist' do
      expect { worker.perform(non_existing_record_id) }.not_to raise_error
    end
  end
end
