# frozen_string_literal: true

module Sbom
  class SyncGroupArchivedStatusService
    OCCURRENCE_BATCH_SIZE = 1_000

    def initialize(group_id)
      @group_id = group_id
    end

    def execute
      return unless group

      each_batch_in_group do |batch|
        batch.update_all(archived: group.self_or_ancestors_archived?)
      end
    end

    private

    def each_batch_in_group
      scope = ::Sbom::Occurrence
        .for_namespace_and_descendants(group)
        .unarchived
        .order_traversal_ids_asc

      iterator = ::Gitlab::Pagination::Keyset::Iterator.new(scope: scope)
      iterator.each_batch(of: OCCURRENCE_BATCH_SIZE) do |batch|
        yield batch
      end
    end

    attr_reader :group_id

    def group
      @group ||= Group.find_by_id(group_id)
    end
  end
end
