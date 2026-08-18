# frozen_string_literal: true

module GitlabSubscriptions
  module DuoCore
    DELAY_TODO_NOTIFICATION = 7.days

    def self.any_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(
        namespace,
        add_on: :duo_core
      ).execute.any?
    end
  end
end
