# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete Epic', :js, feature_category: :portfolio_management do
  include Spec::Support::Helpers::ModalHelpers

  let(:user) { create(:user) }
  let(:group) { create(:group, :public) }
  let(:epic) { create(:epic, group: group) }
  let!(:epic2) { create(:epic, group: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  context 'when user who is not a group member displays the epic' do
    before do
      visit group_epic_path(group, epic)
    end

    it 'does not show the `Delete epic` button' do
      click_button _('More actions'), match: :first

      expect(page).not_to have_button _('Delete epic')
    end
  end

  context 'when user with owner access displays the epic' do
    before do
      group.add_owner(user)
      visit group_epic_path(group, epic)
    end

    it 'deletes the issue and redirect to epic list' do
      click_button _('More actions'), match: :first
      click_button _('Delete Epic')
      within_modal do
        click_button _('Delete Epic')
      end

      within('.issuable-list') do
        expect(page).to have_content(epic2.title)
        expect(page).not_to have_content(epic.title)
      end
    end
  end
end
