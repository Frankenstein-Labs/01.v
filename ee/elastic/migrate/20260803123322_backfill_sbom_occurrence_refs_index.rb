# frozen_string_literal: true

class BackfillSbomOccurrenceRefsIndex < Elastic::Migration
  include ::Search::Elastic::MigrationDatabaseBackfillHelper

  batch_size 10_000
  batched!
  throttle_delay 15.seconds
  retry_on_failure

  DOCUMENT_TYPE = Sbom::OccurrenceRef

  def respect_limited_indexing?
    false
  end

  def item_to_preload
    { project: :namespace }
  end
end
