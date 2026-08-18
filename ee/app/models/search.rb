# frozen_string_literal: true

module Search
  INDEX_PARTITIONING_HASHING_MODULO = 1024
  DEFAULT_CONCURRENCY_LIMIT = 500

  def self.table_name_prefix
    'search_'
  end

  def self.hash_namespace_id(namespace_id, maximum: INDEX_PARTITIONING_HASHING_MODULO)
    return unless namespace_id.present?

    namespace_id.to_s.hash % maximum
  end

  def self.default_concurrency_limit
    DEFAULT_CONCURRENCY_LIMIT
  end
end
