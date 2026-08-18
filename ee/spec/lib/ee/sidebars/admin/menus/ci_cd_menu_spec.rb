# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::Admin::Menus::CiCdMenu, feature_category: :navigation do
  describe '#render?', :enable_admin_mode do
    let(:context) { Sidebars::Context.new(current_user: user, container: nil) }
    let(:menu) { described_class.new(context) }

    subject(:render?) { menu.render? }

    context 'with a non-admin user' do
      let_it_be_with_refind(:user) { create(:user) }

      before do
        stub_licensed_features(custom_roles: true)
      end

      it { is_expected.to be(false) }

      context 'with read_admin_cicd ability' do
        let_it_be(:role) { create(:member_role, :read_admin_cicd) }
        let_it_be(:user_member_role) { create(:user_member_role, member_role: role, user: user) }

        it { is_expected.to be(true) }
      end
    end
  end
end
