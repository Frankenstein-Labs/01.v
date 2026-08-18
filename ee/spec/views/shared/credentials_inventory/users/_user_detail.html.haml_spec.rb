# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'shared/credentials_inventory/users/_user_detail.html.haml', feature_category: :system_access do
  let(:user) { build_stubbed(:user) }
  let(:deleted_user) { '' }

  context 'when a user exists' do
    before do
      allow(view).to receive(:user_detail_path).with(user).and_return("/admin/users/#{user.username}")

      render 'shared/credentials_inventory/users/user_detail',
        user: user
    end

    it 'renders the user details (Creator)' do
      expect(rendered).to have_text(user.name)
      expect(rendered).to have_link(href: "/admin/users/#{user.username}")

      expect(rendered).to have_text(user.email)
      expect(rendered).to have_link(href: "mailto:#{user.email}")
    end
  end

  context 'when a user does not exist' do
    before do
      render 'shared/credentials_inventory/users/user_detail',
        user: deleted_user
    end

    it 'renders a deleted user text' do
      expect(rendered).to have_text(s_('CredentialsInventory|Deleted user'))
    end
  end
end
