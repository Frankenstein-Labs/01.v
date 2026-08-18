# frozen_string_literal: true

module ArtifactRegistry
  class Page
    attr_reader :nodes, :next_cursor, :prev_cursor

    def initialize(nodes:, next_cursor: nil, prev_cursor: nil)
      @nodes = Array(nodes).freeze
      @next_cursor = next_cursor
      @prev_cursor = prev_cursor
    end
  end
end
