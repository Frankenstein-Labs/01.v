# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_head.html.haml', feature_category: :user_management do
  let_it_be(:user) { build(:user) }

  before do
    assign(:user, user)
  end

  context 'when current user can admin all resources' do
    before do
      allow(view).to receive(:can?).with(anything, :admin_all_resources).and_return(true)
      render
    end

    it 'renders admin role badge' do
      expect(rendered).to render_template(partial: 'admin/users/_admin_role_badge')
    end
  end

  context 'when current user cannot admin all resources' do
    before do
      allow(view).to receive(:can?).with(anything, :admin_all_resources).and_return(false)
      render
    end

    it 'does not render admin role badge' do
      expect(rendered).not_to render_template(partial: 'admin/users/_admin_role_badge')
    end
  end
end
