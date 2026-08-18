# frozen_string_literal: true

RSpec.shared_examples 'seat alert namespace component' do
  it 'renders purchase more seats link' do
    expect(component).to have_link('Purchase more seats')
  end

  it 'renders the dismiss endpoint' do
    expect(component.to_html).to include('group_callouts')
  end

  it 'renders the group id' do
    expect(component).to have_css("[data-group-id='#{group.id}']")
  end

  context 'when restricted access is enabled' do
    let(:seat_control) { :block_overages }

    it 'renders turn off restricted access button' do
      expect(component).to have_link('Turn off restricted access', href: /edit#js-permissions-settings/)
    end
  end

  context 'when restricted access is disabled' do
    let(:seat_control) { :off }

    it 'renders turn on restricted access button' do
      expect(component).to have_link('Turn on restricted access', href: /edit#js-permissions-settings/)
    end
  end
end
