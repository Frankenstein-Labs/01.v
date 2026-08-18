# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/security/dashboard/show.html.haml', feature_category: :vulnerability_management do
  def force_fluid_layout
    view.instance_variable_get(:@force_fluid_layout)
  end

  let(:group) { build_stubbed(:group) }

  before do
    assign(:group, group)
  end

  it 'renders the placeholder for the UI component' do
    render

    expect(rendered).to have_selector('#js-group-security-dashboard')
  end

  context 'when user has access_advanced_vulnerability_management ability' do
    before do
      allow(view).to receive(:can?).with(anything, :access_advanced_vulnerability_management, group).and_return(true)
    end

    it 'sets the page to fluid layout' do
      render

      expect(force_fluid_layout).to be(true)
    end
  end

  context 'when user does not have access_advanced_vulnerability_management ability' do
    before do
      allow(view).to receive(:can?).with(anything, :access_advanced_vulnerability_management, group).and_return(false)
    end

    it 'does not set the page to fluid layout' do
      render

      expect(force_fluid_layout).to be(false)
    end
  end
end
