# frozen_string_literal: true

module Features
  module TrialWidgetHelpers
    def expect_widget_to_have_content(widget_title)
      within_testid(widget_menu_selector) do
        expect(page).to have_content(widget_title)
      end
    end

    def expect_widget_title_to_be(widget_title)
      within_testid('trial-widget-menu') do
        expect(page).to have_selector('[data-testid="widget-title"]', text: widget_title)
      end
    end

    def dismiss_widget
      within_testid(widget_root_element) do
        find_by_testid('close-icon').click
      end
    end

    def expect_widget_not_to_be_present
      expect(page).not_to have_testid(widget_root_element)
    end

    def widget_menu_selector
      'trial-widget-menu'
    end

    def widget_root_element
      'trial-widget-root-element'
    end

    def expect_widget_not_visible
      expect(page).not_to have_testid(widget_root_element)
    end
  end
end
