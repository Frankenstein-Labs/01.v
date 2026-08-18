# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'password complexity validations' do
  let(:basic_rules) { [] }
  let(:complexity_rules) { [] }
  let(:all_rules) { basic_rules + complexity_rules }

  context 'when password complexity feature is not available' do
    before do
      stub_licensed_features(password_complexity: false)
      stub_application_setting(password_number_required: true)
    end

    context 'when no rule is required' do
      before do
        visit path_to_visit
      end

      it 'does not render any rule' do
        expect(page).not_to have_selector('[data-testid="password-rule-text"]')
      end
    end
  end

  context 'when password complexity feature is available' do
    before do
      stub_licensed_features(password_complexity: true)
    end

    context 'when no complexity rule is required' do
      before do
        visit path_to_visit
      end

      it 'renders only basic rules' do
        basic_rules.each do |rule|
          expect(page).to have_selector("[data-testid=\"password-#{rule}-status-icon\"]", count: 1)
        end

        expect(page).to have_selector('[data-testid="status_created_borderless-icon"]', count: basic_rules.size)
        expect(page).to have_selector('[data-testid="password-rule-text"]', count: basic_rules.size)
      end
    end

    context 'when two complexity rules are required' do
      let(:complexity_rules) { [:number, :lowercase] }

      before do
        stub_application_setting(password_number_required: true)
        stub_application_setting(password_lowercase_required: true)

        visit path_to_visit
      end

      it 'shows basic rules and two complexity rules' do
        all_rules.each do |rule|
          expect(page).to have_selector("[data-testid=\"password-#{rule}-status-icon\"]", count: 1)
        end

        expect(page).to have_selector('[data-testid="status_created_borderless-icon"]', count: all_rules.size)
        expect(page).to have_selector('[data-testid="password-rule-text"]', count: all_rules.size)
      end
    end

    context 'when all passsword rules are required' do
      include_context 'with all password complexity rules enabled'

      before do
        visit path_to_visit
        fill_in password_input_selector, with: password
      end

      context 'password does not meet all rules' do
        let(:password) { 'aaaAAA!!!' }
        let(:complexity_rules) { [:number] }

        it 'does not show check for not matched rules' do
          all_rules.each do |rule|
            expect(page).to have_selector("[data-testid=\"password-#{rule}-status-icon\"]", count: 1)
          end

          expect(page).to have_selector(
            '[data-testid="status_created_borderless-icon"]',
            count: complexity_rules.size
          )
        end
      end

      context 'when clicking on submit button' do
        context 'when password rules are not fully matched' do
          let(:password) { 'bbbbBBBB' }
          let(:complexity_rules) { [:number, :symbol] }

          it 'highlights not matched rules' do
            expect(page).to have_selector('[data-testid="close-icon"].gl-text-danger', count: 0)
            expect(page).to have_selector('[data-testid="password-rule-text"].gl-text-danger', count: 0)

            click_button submit_button_selector

            expect(page).to have_selector(
              '[data-testid="close-icon"].gl-text-danger',
              count: complexity_rules.size
            )

            expect(page).to have_selector(
              '[data-testid="password-rule-text"].gl-text-danger',
              count: complexity_rules.size
            )
          end
        end
      end
    end
  end
end
