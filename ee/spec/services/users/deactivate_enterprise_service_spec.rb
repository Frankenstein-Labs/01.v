# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::DeactivateEnterpriseService, feature_category: :seat_cost_management do
  let_it_be(:current_user) { build(:admin) }
  let_it_be(:enterprise_group) { create(:group) }

  subject(:service) { described_class.new(current_user, group: enterprise_group) }

  describe '#execute', :enable_admin_mode do
    context 'with the enterprise user in the given group' do
      let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: enterprise_group) }

      it 'deactivates the user' do
        expect(service.execute(user)).to be_success

        expect(user.reload.deactivated?).to be true
      end
    end

    context 'with enterprise user in different group' do
      let_it_be_with_reload(:user) { create(:enterprise_user) }

      it 'does not deactivate the user' do
        result = service.execute(user)

        expect(result).to be_error
        expect(result.message).to match(/cannot be deactivated/)
      end
    end

    context 'with non-enterprise user' do
      let_it_be_with_reload(:user) { create(:user) }

      it 'does not deactivate the user' do
        result = service.execute(user)

        expect(result).to be_error
        expect(result.message).to match(/cannot be deactivated/)
      end
    end
  end
end
