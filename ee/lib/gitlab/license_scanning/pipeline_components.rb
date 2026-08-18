# frozen_string_literal: true

module Gitlab
  module LicenseScanning
    class PipelineComponents
      def initialize(pipeline:)
        @pipeline = pipeline
      end

      def fetch
        pipeline.sbom_reports.reports.flat_map do |sbom_report|
          sbom_report.components.map do |component|
            next unless component.purl
            next unless supported_for_license_scanning?(component.purl.type)

            Hashie::Mash.new(name: component.name,
              purl_type: component.purl.type,
              version: component.version,
              path: sbom_report.source&.input_file_path,
              licenses: component.licenses)
          end.reject(&:blank?)
        end
      end

      private

      attr_reader :pipeline

      def supported_for_license_scanning?(purl_type)
        ::Enums::Sbom.dependency_scanning_purl_type?(purl_type)
      end
    end
  end
end
