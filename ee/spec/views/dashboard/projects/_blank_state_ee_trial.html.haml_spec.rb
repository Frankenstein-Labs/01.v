# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'dashboard/projects/_blank_state_ee_trial.html.haml', feature_category: :user_profile do
  include LicenseHelper

  it 'links to internal trial path' do
    render

    expect(rendered).to have_link('Start free trial', href: new_self_managed_trials_path)
  end

  it 'tracks the start trial CTA click' do
    render

    expect(rendered).to trigger_internal_events('click_start_trial_cta_sm_project_dashboard').on_click
  end
end
