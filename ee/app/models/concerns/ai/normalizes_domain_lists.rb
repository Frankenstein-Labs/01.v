# frozen_string_literal: true

module Ai
  module NormalizesDomainLists
    extend ActiveSupport::Concern

    included do
      before_validation :normalize_domain_lists
    end

    private

    def normalize_domain_lists
      self.allowed_domains = allowed_domains&.map(&:downcase)
      self.denied_domains = denied_domains&.map(&:downcase)
    end
  end
end
