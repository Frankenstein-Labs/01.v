# frozen_string_literal: true

module PackageMetadata
  module DataObjects
    class CveEnrichment
      def self.create(data, _purl_type)
        new(**data.transform_keys(&:to_sym))
      end

      attr_accessor :cve_id, :epss_score, :is_known_exploit

      def initialize(cve_id:, epss_score:, is_known_exploit: false)
        @cve_id = cve_id
        @epss_score = epss_score
        @is_known_exploit = is_known_exploit
      end

      def ==(other)
        return false unless other.is_a?(self.class)

        cve_id == other.cve_id &&
          epss_score == other.epss_score &&
          is_known_exploit == other.is_known_exploit
      end
    end
  end
end
