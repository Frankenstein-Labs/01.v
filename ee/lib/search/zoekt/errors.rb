# frozen_string_literal: true

module Search
  module Zoekt
    module Errors
      BaseError = Class.new(StandardError)
      ClientConnectionError = Class.new(BaseError)
    end
  end
end
