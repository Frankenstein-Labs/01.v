# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/index', :enable_admin_mode, feature_category: :user_management do
  let(:admin) { build_stubbed(:user, :admin) }

  before do
    allow(view).to receive_messages(container_class: 'ignored', current_user: admin)
    create(:user) # to have at least one user
    assign(:users, User.all.page(1))
    assign(:cohorts, { months_included: 0, cohorts: [] })

    render
  end

  it 'includes "Send email to users" link' do
    expect(rendered).to have_link href: admin_email_path
  end
end
