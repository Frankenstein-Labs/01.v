# frozen_string_literal: true

module ArtifactRegistry
  class NpmPackage
    def initialize(attributes = {})
      @attributes = attributes || {}
    end

    def id
      @attributes['id']
    end

    def name
      @attributes['name']
    end

    def scope
      @attributes['scope']
    end

    def versions_count
      @attributes['versions_count']
    end
  end
end
