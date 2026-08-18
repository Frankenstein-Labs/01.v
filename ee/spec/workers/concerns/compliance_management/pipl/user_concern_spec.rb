# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Pipl::UserConcern, :saas, feature_category: :compliance_management do
  describe '#belongs_to_paid_group?' do
    let_it_be_with_reload(:user) { create(:user) }
    let(:klass) do
      Class.new do
        include ComplianceManagement::Pipl::UserConcern
      end
    end

    subject(:paid) { klass.new.belongs_to_paid_group?(user) }

    context 'when the user is member of a paid group' do
      before do
        create(:group_with_plan, plan: :ultimate_plan, guests: user)
      end

      it 'returns true' do
        expect(paid).to be(true)
      end
    end

    context 'when the user is not a member of a paid group' do
      it 'returns false' do
        expect(paid).to be(false)
      end
    end
  end
end
