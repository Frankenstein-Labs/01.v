# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'projects/get_started/show', :aggregate_failures, feature_category: :onboarding do
  before do
    onboarding_progress = build_stubbed(:onboarding_progress)

    presenter = instance_double(Onboarding::GetStartedPresenter, view_model: '{"sections":[]}', provide: '{}')
    assign(:get_started_presenter, presenter)
    allow(view).to receive_messages(onboarding_progress: onboarding_progress, current_user: build_stubbed(:user))

    render
  end

  it 'hides broadcast messages' do
    expect(view.content_for(:hide_broadcast_messages)).to be_truthy
  end

  it 'renders the get started app container' do
    expect(rendered).to have_css('#js-get-started-app')
  end

  it 'passes the presenter attributes to the frontend' do
    expect(rendered).to have_css('#js-get-started-app[data-view-model=\'{"sections":[]}\']')
  end
end
