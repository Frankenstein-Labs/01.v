# frozen_string_literal: true

class ElasticAssociationIndexerWorker
  include ApplicationWorker
  include Search::Worker
  prepend ::Geo::SkipSecondary

  data_consistency :delayed

  sidekiq_options retry: 3
  idempotent!
  worker_resource_boundary :cpu
  loggable_arguments 0, 2
  pause_control :advanced_search

  def perform(class_name, id, indexed_associations)
    return unless Gitlab::CurrentSettings.elasticsearch_indexing?

    klass = class_name.constantize
    object = klass.find_by_id(id)
    return unless object&.use_elasticsearch?

    Elastic::ProcessBookkeepingService.maintain_indexed_associations(object, indexed_associations)
  end
end
