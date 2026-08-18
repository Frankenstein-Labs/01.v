# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'layouts/application' do
  let_it_be(:user) { create(:user) }

  before do
    allow(view).to receive(:session).and_return({})
    allow(view).to receive(:user_signed_in?).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:current_user_mode).and_return(Gitlab::Auth::CurrentUserMode.new(user))
  end

  it_behaves_like 'a layout which reflects the application theme setting'
  it_behaves_like 'a layout which reflects the preferred language'
end
