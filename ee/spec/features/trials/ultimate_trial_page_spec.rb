# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Ultimate Trial Page', :js, :saas, feature_category: :acquisition do
  let_it_be(:user) { create(:user) }

  before do
    sign_in(user)
  end

  it 'shows the new title' do
    visit new_trial_path

    expect(page).to have_title('Start your free Ultimate trial')
  end
end
