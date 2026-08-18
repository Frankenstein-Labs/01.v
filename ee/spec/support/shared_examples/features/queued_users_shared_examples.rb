# frozen_string_literal: true

RSpec.shared_examples 'queued users' do
  let_it_be(:license, freeze: false) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:first_user, freeze: false) { create(:user) }
  let_it_be(:second_user, freeze: false) { create(:user) }
  let_it_be(:error_user, freeze: false) { create(:user) }
  let(:role) { 'Developer' }

  before do
    stub_application_setting(enable_member_promotion_management: true)
    allow(License).to receive(:current).and_return(license)
    sign_in(user1)
  end

  before_all do
    group.add_owner(user1)
    group.add_owner(error_user)
  end

  context 'when queued warning message shows due to other errors' do
    it 'fails with an error and shows warning', :js do
      visit subentity_members_page_path

      invite_member([first_user.name, second_user.name, error_user.name], role: role)

      invite_modal = page.find(invite_modal_selector)
      expect_to_have_warning_invite_indicator(invite_modal, first_user)
      expect_to_have_warning_invite_indicator(invite_modal, second_user)
    end

    def expect_to_have_warning_invite_indicator(page, user)
      expect(page).to have_selector("#{member_token_selector(user.id)} .gl-bg-orange-100")
      expect(page).to have_selector(member_token_warning_selector(user.id))
    end

    def member_token_warning_selector(id)
      "[data-testid='warning-icon-#{id}']"
    end
  end
end
