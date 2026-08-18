# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Operations/Environments navigation', :js, feature_category: :navigation do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)

    stub_licensed_features(operations_dashboard: true)

    visit root_path
  end

  it 'has an `Operations` link' do
    expect(page).to have_link('Operations', href: operations_path)
  end

  it 'has an `Environments` link' do
    expect(page).to have_link('Environments', href: operations_environments_path)
  end
end
