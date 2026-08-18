# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "projects/security/sast_configuration/show", feature_category: :static_application_security_testing, type: :view do
  before do
    @project = build_stubbed(:project)
    render
  end

  it 'renders Vue app root' do
    expect(rendered).to have_selector('.js-sast-configuration')
  end
end
