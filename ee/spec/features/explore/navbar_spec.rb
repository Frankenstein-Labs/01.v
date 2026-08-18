# frozen_string_literal: true

require 'spec_helper'

RSpec.describe '"Explore" navbar (EE)', :js, feature_category: :navigation do
  context 'when AI Catalog is available for the instance' do
    before do
      allow(Ai::Catalog).to receive(:feature_available?).and_return(true)
      visit explore_root_path
    end

    it 'shows AI Catalog menu item' do
      within_testid('non-static-items-section') do
        expect(page).to have_text('AI Catalog')
      end
    end
  end

  context 'when AI Catalog is not available for the instance' do
    before do
      allow(Ai::Catalog).to receive(:feature_available?).and_return(false)
      visit explore_root_path
    end

    it 'does not show AI Catalog menu item' do
      within_testid('non-static-items-section') do
        expect(page).not_to have_text('AI Catalog')
      end
    end
  end
end
