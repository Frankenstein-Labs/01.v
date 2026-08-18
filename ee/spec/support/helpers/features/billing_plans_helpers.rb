# frozen_string_literal: true

require_relative 'hand_raise_lead_helpers'

#  We write these in helper methods so that JH can override them
#  Related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/361718
module Features
  module BillingPlansHelpers
    include HandRaiseLeadHelpers

    def should_have_hand_raise_lead_button
      expect(page).to have_selector(".js-hand-raise-lead-trigger", visible: :hidden)
    end
  end
end

Features::BillingPlansHelpers.prepend_mod
