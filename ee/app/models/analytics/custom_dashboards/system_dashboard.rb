# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class SystemDashboard
      include GlobalID::Identification

      attr_reader :slug, :config

      def initialize(slug:, config:)
        @slug = slug
        @config = config
      end

      def id
        "gitlab:dashboard:#{slug}"
      end

      def name
        config['title']
      end

      def description
        config['description']
      end

      def system?
        true
      end

      def readonly?
        true
      end

      def persisted?
        true
      end

      def created_at
        nil
      end
    end
  end
end
