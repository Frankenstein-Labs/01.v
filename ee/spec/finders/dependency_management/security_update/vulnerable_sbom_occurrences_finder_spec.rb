# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::VulnerableSbomOccurrencesFinder,
  feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:archived_project) { create(:project, :archived) }

  let(:package_manager) { :bundler }
  let(:severity_level) { :high }

  subject(:finder) do
    described_class.new(project: project, package_manager: package_manager, severity_level: severity_level)
  end

  describe '#execute_in_batches' do
    context 'when project is archived' do
      let(:project) { archived_project }

      it 'returns nil without yielding' do
        expect { |b| finder.execute_in_batches(&b) }.not_to yield_control
      end
    end

    context 'when package manager is supported' do
      let_it_be(:vulnerability_critical) { create(:vulnerability, :critical, project: project) }
      let_it_be(:vulnerability_high) { create(:vulnerability, :high, project: project) }
      let_it_be(:vulnerability_high_2) { create(:vulnerability, :high, project: project) }
      let_it_be(:vulnerability_medium) { create(:vulnerability, :medium, project: project) }
      let_it_be(:vulnerability_dismissed) { create(:vulnerability, :dismissed, project: project) }

      let_it_be(:occurrence_bundler_critical) do
        create(:sbom_occurrence, project: project, packager_name: 'bundler',
          highest_severity: 'critical').tap do |occurrence|
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_critical)
        end
      end

      let_it_be(:occurrence_bundler_high) do
        create(:sbom_occurrence, project: project, packager_name: 'bundler',
          highest_severity: 'high').tap do |occurrence|
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_high)
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_high_2)
        end
      end

      let_it_be(:occurrence_bundler_medium) do
        create(:sbom_occurrence, project: project, packager_name: 'bundler',
          highest_severity: 'medium').tap do |occurrence|
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_medium)
        end
      end

      let_it_be(:occurrence_bundler_dismissed) do
        create(:sbom_occurrence, project: project, packager_name: 'bundler').tap do |occurrence|
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_dismissed)
        end
      end

      let_it_be(:occurrence_npm) do
        create(:sbom_occurrence, project: project, packager_name: 'npm').tap do |occurrence|
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_critical)
        end
      end

      let_it_be(:occurrence_without_version) do
        create(:sbom_occurrence, project: project, packager_name: 'bundler', component_version: nil).tap do |occurrence|
          create(:sbom_occurrences_vulnerability, occurrence: occurrence, vulnerability: vulnerability_critical)
        end
      end

      let_it_be(:occurrence_without_vulnerability) do
        create(:sbom_occurrence, project: project, packager_name: 'bundler')
      end

      it 'yields batches of vulnerable SBOM occurrences at specified severity level' do
        yielded_occurrences = []

        finder.execute_in_batches do |batch|
          yielded_occurrences.concat(batch.to_a)
        end

        expect(yielded_occurrences).to eq([occurrence_bundler_high])
      end

      it 'excludes occurrences with dismissed vulnerabilities' do
        yielded_occurrences = []

        finder.execute_in_batches do |batch|
          yielded_occurrences.concat(batch.to_a)
        end

        expect(yielded_occurrences).not_to include(occurrence_bundler_dismissed)
      end

      it 'excludes occurrences from unspecified package manager' do
        yielded_occurrences = []

        finder.execute_in_batches do |batch|
          yielded_occurrences.concat(batch.to_a)
        end

        expect(yielded_occurrences).not_to include(occurrence_npm)
      end

      it 'excludes occurrences without component versions' do
        yielded_occurrences = []

        finder.execute_in_batches do |batch|
          yielded_occurrences.concat(batch.to_a)
        end

        expect(yielded_occurrences).not_to include(occurrence_without_version)
      end

      it 'excludes occurrences without vulnerabilities' do
        yielded_occurrences = []

        finder.execute_in_batches do |batch|
          yielded_occurrences.concat(batch.to_a)
        end

        expect(yielded_occurrences).not_to include(occurrence_without_vulnerability)
      end

      it 'returns distinct occurrences' do
        # Create a second vulnerability for the same occurrence
        create(:sbom_occurrences_vulnerability,
          occurrence: occurrence_bundler_critical,
          vulnerability: vulnerability_high)

        yielded_occurrences = []

        finder.execute_in_batches do |batch|
          yielded_occurrences.concat(batch.to_a)
        end

        occurrence_ids = yielded_occurrences.map(&:id)
        expect(occurrence_ids.uniq).to eq(occurrence_ids)
      end

      context 'when preloading vulnerabilities and findings' do
        let_it_be(:occurrence_with_finding_1) do
          create(:sbom_occurrence, project: project, packager_name: 'bundler', highest_severity: 'high').tap do |o|
            vuln = create(:vulnerability, :with_finding, :high, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: o, vulnerability: vuln)
          end
        end

        let_it_be(:occurrence_with_finding_2) do
          create(:sbom_occurrence, project: project, packager_name: 'bundler', highest_severity: 'high').tap do |o|
            vuln = create(:vulnerability, :with_finding, :high, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: o, vulnerability: vuln)
          end
        end

        it 'does not N+1 when accessing findings through vulnerabilities' do
          recorder = ActiveRecord::QueryRecorder.new do
            finder.execute_in_batches do |batch|
              batch.each { |o| o.vulnerabilities.each(&:findings) }
            end
          end

          create(:sbom_occurrence, project: project, packager_name: 'bundler', highest_severity: 'high').tap do |o|
            vuln = create(:vulnerability, :with_finding, :high, project: project)
            create(:sbom_occurrences_vulnerability, occurrence: o, vulnerability: vuln)
          end

          expect do
            finder.execute_in_batches do |batch|
              batch.each { |o| o.vulnerabilities.each(&:findings) }
            end
          end.not_to exceed_query_limit(recorder)
        end
      end
    end
  end
end
