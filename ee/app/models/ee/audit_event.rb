# frozen_string_literal: true

module EE
  module AuditEvent
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    TRUNCATED_FIELDS = {
      entity_path: 5_500,
      target_details: 5_500
    }.freeze

    prepended do
      scope :by_entity, ->(entity_type, entity_id) { by_entity_type(entity_type).by_entity_id(entity_id) }

      before_validation :truncate_fields
    end

    attr_writer :entity
    attr_accessor :root_group_entity_id

    # Stable streaming ID for events that are not persisted (no database
    # `id`). See AuditEvents::CommonAuditEventStreamable#stream_id.
    attr_accessor :stream_id

    def entity
      strong_memoize(:entity) do
        if entity_type == ::Gitlab::Audit::InstanceScope.name
          ::Gitlab::Audit::InstanceScope.new
        else
          lazy_entity
        end
      end
    end

    def root_group_entity
      strong_memoize(:root_group_entity) do
        next ::Group.find_by(id: root_group_entity_id) if root_group_entity_id.present?
        next if entity.nil?

        root_group_entity =
          case entity_type
          when 'Group'
            # Sub group events should be sent to the root ancestor's streaming destinations
            entity.root_ancestor
          when 'Project'
            # Project events should be sent to the root ancestor's streaming destinations
            # Projects without a group root ancestor should be ignored.
            entity.group&.root_ancestor
          end

        self.root_group_entity_id = root_group_entity&.id
        root_group_entity
      end
    end

    def entity_path
      super || details[:entity_path]
    end

    def present
      AuditEventPresenter.new(self)
    end

    def ip_address
      super&.to_s || details[:ip_address]
    end

    def stream_to_external_destinations(use_json: false, event_name: 'audit_operation')
      return unless can_stream_to_external_destination?(event_name)

      # Set at enqueue: log lines read root_namespace from the job payload snapshot, not from context during perform.
      ::Gitlab::ApplicationContext.with_context(namespace: streamable_namespace) do
        ::AuditEvents::Streaming::EnqueueService.new(self, event_name: event_name, use_json: use_json).execute
      end
    end

    def entity_is_group_or_project?
      %w[Group Project].include?(entity_type)
    end

    def streamable_namespace
      case entity_type
      when 'Project'
        entity&.project_namespace || entity&.namespace
      when 'User'
        nil
      when 'Gitlab::Audit::InstanceScope'
        load_target_namespace
      else
        entity if entity.is_a?(::Namespace)
      end
    end
    strong_memoize_attr :streamable_namespace

    private

    def lazy_entity
      BatchLoader.for(entity_id)
                 .batch(
                   key: entity_type, default_value: ::Gitlab::Audit::NullEntity.new
                 ) do |ids, loader, args|
        model = Object.const_get(args[:key], false)
        model.where(id: ids).find_each { |record| loader.call(record.id, record) }
      end
    end

    def can_stream_to_external_destination?(event_name)
      return false if ::Gitlab::SilentMode.enabled?
      return false if entity.nil?

      ::AuditEvents::ExternalDestinationStreamer.new(event_name, self).streamable?
    end

    def truncate_fields
      TRUNCATED_FIELDS.each do |name, limit|
        original = self[name] || self.details[name]
        next unless original

        self[name] = self.details[name] = String(original).truncate(limit)
      end
    end

    def load_target_namespace
      return unless target_type && target_id

      case target_type
      when 'Project'
        lazy_load_target.then { |project| project&.project_namespace }
      when 'Group', 'Namespaces::ProjectNamespace'
        lazy_load_target
      end
    end

    def lazy_load_target
      BatchLoader.for(target_id).batch(
        key: target_type,
        default_value: nil
      ) do |ids, loader, args|
        model = Object.const_get(args[:key], false)
        model.where(id: ids).find_each { |record| loader.call(record.id, record) }
      end
    end
  end
end
