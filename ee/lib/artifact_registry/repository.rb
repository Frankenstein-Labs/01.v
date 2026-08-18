# frozen_string_literal: true

module ArtifactRegistry
  class Repository
    def initialize(attributes = {})
      @attributes = attributes || {}
    end

    def id
      @attributes['id']
    end

    def name
      @attributes['name']
    end

    def format
      @attributes['format']
    end

    def kind
      @attributes['kind']
    end

    def visibility
      @attributes['visibility']
    end

    def description
      @attributes['description']
    end

    def artifacts_count
      @attributes['artifacts_count']
    end

    def downloads_count
      @attributes['downloads_count']
    end

    def size_bytes
      @attributes['size_bytes']
    end

    def created_at
      parse_time(@attributes['created_at'])
    end

    def last_updated_at
      parse_time(@attributes['last_updated_at'])
    end

    def created_by
      @attributes['created_by']
    end

    def updated_by
      @attributes['updated_by']
    end

    def settings
      @attributes['settings'] || {}
    end

    private

    def parse_time(value)
      return unless value

      DateTime.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
