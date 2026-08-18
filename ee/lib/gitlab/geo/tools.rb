# frozen_string_literal: true

module Gitlab
  module Geo
    # SPIKE (gitlab-org/gitlab#602803): console/CLI entry point over the Geo known-error
    # catalog. The geo:tools rake tasks are thin wrappers around these methods, so the same
    # checks can be run from a Rails console without invoking rake (mirrors
    # Gitlab::Geo::GeoTasks).
    module Tools
      extend self

      # Read-only: scan the catalog and print any detected known errors with a suggested fix.
      # Pass a single known error to check only that one, for example when a scan of the whole
      # catalog is more work than an operator needs.
      def cleanup_check(known_error = nil, **options)
        site = ::Gitlab::Geo.primary? ? 'Primary' : 'Secondary'

        puts "Geo Cleanup Check -- #{site} Site"
        puts '=' * 40
        puts "Scanning for #{known_error ? "'#{known_error.name}'" : 'known issues'}...\n\n"

        detected = Array.wrap(known_error || ::Geo::Tools::KnownErrors.catalog(**options)).select(&:detected?)

        if detected.empty?
          puts 'No known issues detected.'
        else
          detected.each_with_index do |known_error, index|
            puts "#{index + 1}. #{known_error.title} (#{known_error.severity})"

            if known_error.match_pattern.present?
              puts "   #{known_error.affected_count_label} records matching '#{known_error.match_pattern}'"
            else
              puts "   #{known_error.affected_count_label} records affected (structural check)"
            end

            if known_error.resolvable
              puts "   -> Run: sudo gitlab-rake \"geo:tools:resolve[#{known_error.name}]\" (dry run by default)"
            else
              puts "   -> Manual intervention required. Docs: #{known_error.docs}"
            end

            puts
          end
        end

        puts "Add DRY_RUN=false to a resolve task to actually apply it."
      end

      # Resolve a known error. Dry run by default; the destructive strategies only act when
      # dry_run is false. Prints a header, the dry-run sample, and the service result.
      def resolve(known_error, dry_run: true, limit: nil)
        puts "Resolving Geo error: #{known_error.title} (dry run mode #{dry_run ? 'ON' : 'OFF'})"
        puts

        if dry_run
          sample = known_error.sample
          puts "Sample of affected records (up to #{sample.size}):"
          sample.each { |line| puts "  #{line}" }
          puts
        end

        response = ::Geo::Tools::ResolveKnownErrorService.new(known_error, dry_run: dry_run, limit: limit).execute
        puts response.message

        response
      end
    end
  end
end
