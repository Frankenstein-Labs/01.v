# frozen_string_literal: true

module EE
  module SignUpHelpers
    def expect_password_to_be_validated
      page.within '[data-testid="password-common-status-icon"]' do
        expect(page).to have_selector('[data-testid="check-icon"]')
      end

      page.within '[data-testid="password-user_info-status-icon"]' do
        expect(page).to have_selector('[data-testid="check-icon"]')
      end
    end
  end
end
