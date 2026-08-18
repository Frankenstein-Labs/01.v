# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_admin_role_badge.html.haml', feature_category: :user_management do
  let_it_be(:user) { build(:user) }
  let_it_be(:role) { build(:member_role, :admin) }

  shared_examples 'does not show admin role badge' do
    it { is_expected.not_to have_css('.badge-info', text: role.name) }
    it { is_expected.not_to have_testid('admin-icon') }
  end

  before do
    assign(:user, user)
  end

  context 'when the user is assigned an admin role' do
    before do
      allow(user).to receive(:member_role).and_return(role)
      stub_licensed_features(custom_roles: true)
      render
    end

    it 'shows admin role badge' do
      expect(rendered).to have_css('.badge-info', text: role.name)
      expect(rendered).to have_testid('admin-icon')
    end

    context 'when license does not have access to custom roles' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it_behaves_like 'does not show admin role badge'
    end
  end

  context 'when the user is not assigned an admin role' do
    before do
      allow(user).to receive(:member_role).and_return(nil)
      stub_licensed_features(custom_roles: true)
      render
    end

    it_behaves_like 'does not show admin role badge'
  end
end
