# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/merge_requests/_merge_requests', feature_category: :duo_chat do
  let_it_be(:group) { build(:group, namespace_settings: build(:namespace_settings)) }

  before do
    assign(:group, group)
    allow(group).to receive(:licensed_feature_available?).and_return(false)
  end

  context 'when duo_features_enabled is false' do
    before do
      allow(group).to receive(:duo_features_enabled).and_return(false)
    end

    it 'does not render the Duo Code Review section' do
      render locals: { expanded: false }

      expect(rendered).not_to have_content 'GitLab Duo Code Review'
    end
  end

  context 'when duo_features_enabled is true' do
    before do
      allow(group).to receive(:duo_features_enabled).and_return(true)
    end

    context 'when auto_duo_code_review_settings_available? is true' do
      before do
        allow(group).to receive(:auto_duo_code_review_settings_available?).and_return(true)
      end

      it 'renders the Duo Code Review section' do
        render locals: { expanded: false }

        expect(rendered).to have_content 'GitLab Duo Code Review'
      end

      it 'renders an enabled checkbox' do
        render locals: { expanded: false }

        expect(rendered).not_to have_css('input[name="namespace_setting[auto_duo_code_review_enabled]"][disabled]')
      end
    end

    context 'when auto_duo_code_review_settings_available? is false' do
      before do
        allow(group).to receive(:auto_duo_code_review_settings_available?).and_return(false)
      end

      it 'renders the Duo Code Review section' do
        render locals: { expanded: false }

        expect(rendered).to have_content 'GitLab Duo Code Review'
      end

      it 'renders a disabled checkbox with a help link', :aggregate_failures do
        render locals: { expanded: false }

        expect(rendered).to have_css('input[name="namespace_setting[auto_duo_code_review_enabled]"][disabled]')
        expect(rendered).to have_content 'Requires the Code Review foundational flow to be enabled'
      end
    end
  end
end
