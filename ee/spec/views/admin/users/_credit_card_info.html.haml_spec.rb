# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/_credit_card_info.html.haml', :saas, feature_category: :system_access do
  include ApplicationHelper

  let_it_be_with_reload(:user) { create(:user) }

  def render
    super(
      partial: 'admin/users/credit_card_info',
      formats: :html,
      locals: { user: user, link_to_match_page: true }
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
        :credit_card_validation,
        user: user,
        network: 'AmericanExpress',
        last_digits: 2,
        credit_card_validated_at: Date.parse('2023-09-20')
      )

      render
    end

    it 'shows validated_at date' do
      expect(rendered).to have_content('Validated at:')
      expect(rendered).to have_content('Sep 20, 2023')
    end

    it 'shows card matches link' do
      expect(rendered).to have_link('View card matches', href: card_match_admin_user_path(user))
    end
  end
end
