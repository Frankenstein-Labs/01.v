# frozen_string_literal: true

module ArtifactRegistry
  class Image
    def initialize(attributes = {})
      @attributes = attributes || {}
    end

    def id
      @attributes['id']
    end

    def name
      @attributes['name']
    end
  end
end
