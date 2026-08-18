# frozen_string_literal: true

module Gitlab
  module Ci
    module Parsers
      module Sbom
        class Cyclonedx
          def parse!(blob, sbom_report)
            @report = sbom_report
            @data = Gitlab::Json.parse(blob)

            return unless valid?

            parse_report
          rescue JSON::ParserError => parse_error
            report.add_error("Report JSON is invalid: #{parse_error}")
          rescue StandardError => e
            report.add_error("Unexpected error encountered")
            ErrorTracking.track_exception(e)
          end

          private

          attr_reader :json_data, :report, :data

          def schema_validator
            @schema_validator ||= Validators::CyclonedxSchemaValidator.new(data)
          end

          def valid?
            valid_schema?
          end

          def valid_schema?
            return true if schema_validator.valid?

            schema_validator.errors.each { |error| report.add_error(error) }

            false
          end

          def parse_report
            parse_metadata_properties
            parse_components
            parse_dependencies
            report.ensure_ancestors!
          end

          def parse_metadata_properties
            properties = data.dig('metadata', 'properties')
            source = CyclonedxProperties.parse_source(properties)

            tools = data.dig('metadata', 'tools')
            authors = data.dig('metadata', 'authors')

            component_data = data.dig('metadata', 'component')
            metadata_component_parser = CyclonedxMetadataComponent.new(component_data)

            component = metadata_component_parser.parse_component
            report.set_metadata_component(component) if component

            if source
              files = metadata_component_parser.parse_files
              source.data['files'] = files if files.present?
              report.set_source(source)
            end

            report.metadata = ::Gitlab::Ci::Reports::Sbom::Metadata.new.tap do |metadata|
              metadata.tools = tools if tools
              metadata.authors = authors if authors
              metadata.properties = properties if properties
            end
          end

          def parse_components
            data['components']&.each do |component_data|
              component = Component.new(component_data).parse
              report.add_component(component) if component.ingestible?
            rescue ::Sbom::PackageUrl::InvalidPackageUrl => exception
              log_invalid_component(component_data['purl'], exception.message)
            end
          end

          # Skipped components are not fatal, so log them to measure how often and why this happens.
          def log_invalid_component(purl, reason)
            Gitlab::AppJsonLogger.warn(
              message: 'Skipped SBOM component with invalid PURL',
              purl: purl,
              invalid_component_reason: reason
            )
          end

          def parse_dependencies
            data['dependencies']&.each do |dependency_data|
              ref = dependency_data['ref']
              dependency_data['dependsOn']&.each do |dependency_ref|
                report.add_dependency(ref, dependency_ref)
              end
            end
          end
        end
      end
    end
  end
end
