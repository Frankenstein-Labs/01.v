# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_phone_info.html.haml', :saas, feature_category: :system_access do
  include ApplicationHelper

  let_it_be_with_reload(:user) { create(:user) }

  def render
    super(
      partial: 'admin/users/phone_info',
      formats: :html,
      locals: {
        user: user,
        link_to_match_page: true
      }
    )
  end

  it 'does not show validated_at date' do
    render

    expect(rendered).to have_content('Validated:')
    expect(rendered).to have_content('No')
  end

  context 'when user is validated' do
    before do
      create(
        :phone_number_validation,
        user: user,
        validated_at: Date.parse('2023-09-20'),
        international_dial_code: 1,
        phone_number: '123456789',
        country: 'US'
      )
    end

    it 'shows matches link' do
      render

      expect(rendered).to have_link('View phone number matches', href: phone_match_admin_user_path(user))
    end

    it 'shows validated_at date' do
      render

      expect(rendered).to have_content('Validated at:')
      expect(rendered).to have_content('Sep 20, 2023')
    end

    it 'shows last attempted number' do
      render

      expect(rendered).to have_content('Last attempted number:')
      expect(rendered).to have_content('+1 123456789 (US)')
    end
  end
end
