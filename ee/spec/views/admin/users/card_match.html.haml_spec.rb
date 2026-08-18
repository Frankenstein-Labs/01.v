# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/users/card_match.html.haml', feature_category: :system_access do
  let(:credit_card_validations) { build_list(:credit_card_validation, 1, user: user) }

  before do
    assign(:user, user)
    assign(:similar_credit_card_validations, Kaminari.paginate_array(credit_card_validations).page(1))

    render
  end

  context 'when user is not banned or blocked' do
    let(:user) { build(:user, created_at: 1.day.ago) }

    it 'renders without indicating that the user is banned or blocked', :aggregate_failures do
      expect(rendered).not_to have_selector('.badge-danger', text: 'Banned')
      expect(rendered).not_to have_selector('.badge-danger', text: 'Blocked')
    end
  end

  context 'when user is banned' do
    let(:user) { build(:user, :banned, created_at: 1.day.ago) }

    it 'renders indicating that the user is banned' do
      expect(rendered).to have_selector('.badge-danger', text: 'Banned')
    end
  end

  context 'when user is blocked' do
    let(:user) { build(:user, :blocked, created_at: 1.day.ago) }

    it 'renders indicating that the user is blocked' do
      expect(rendered).to have_selector('.badge-danger', text: 'Blocked')
    end
  end
end
