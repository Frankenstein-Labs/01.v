# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::PossiblyAffectedOccurrencesFinder, feature_category: :software_composition_analysis do
  let_it_be(:project) { create(:project) }
  let_it_be(:matching_component) { create(:sbom_component, name: 'matching-package', purl_type: 'npm') }
  let_it_be(:non_matching_component) { create(:sbom_component, name: 'non-matching-package', purl_type: 'golang') }
  let_it_be(:matching_source_package) { create(:sbom_source_package, purl_type: 'deb', name: 'perl') }
  let_it_be(:non_matching_source_package) { create(:sbom_source_package, purl_type: 'deb', name: 'perl-base') }

  shared_examples 'preloads assocations' do
    it 'avoids an N+1 query' do
      described_class.new(purl_type: purl_type, package_name: package_name
      ).execute_in_batches do |batch|
        batch.each do |record|
          queries = ActiveRecord::QueryRecorder.new do
            record.component
            record.component_version
            record.source
            record.pipeline
            record.project
          end
          expect(queries.count).to be_zero
        end
      end
    end
  end

  shared_examples 'non-matching component' do
    context 'and no component matches the provided details' do
      context 'as the package_name does not match' do
        let_it_be(:package_name) { 'non-matching-package-name' }

        it 'returns nil' do
          expect(described_class.new(purl_type: purl_type, package_name: package_name)
            .execute_in_batches).to be_nil
        end

        it { expect(possibly_affected_occurrences).to be_empty }
      end

      context 'as the purl_type does not match' do
        let_it_be(:purl_type) { 'non-matching-purl-type' }

        it 'returns nil' do
          expect(described_class.new(purl_type: purl_type, package_name: package_name)
            .execute_in_batches).to be_nil
        end

        it { expect(possibly_affected_occurrences).to be_empty }
      end
    end
  end

  shared_examples 'matching component' do
    context 'and a component matches the provided details' do
      it_behaves_like 'preloads assocations'

      it 'returns the possibly affected occurrences' do
        expect(possibly_affected_occurrences).to match_array(matching_occurrences)
      end

      it 'does not execute an N+1 query' do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) { possibly_affected_occurrences.first }

        create_list(:sbom_component_version, 3, component: matching_component)

        expect { possibly_affected_occurrences.first }.not_to exceed_all_query_limit(control)
      end

      context 'and an sbom occurrence exists without a version' do
        let_it_be(:sbom_occurrence_without_component_version) do
          create(:sbom_occurrence, component: matching_component, component_version: nil)
        end

        it 'does not return the sbom occurrence without a component version' do
          expect(possibly_affected_occurrences).not_to include(sbom_occurrence_without_component_version)
        end
      end
    end
  end

  # use a method instead of a subject to avoid rspec memoization
  def possibly_affected_occurrences
    occurrences = []
    described_class.new(purl_type: purl_type, package_name: package_name).execute_in_batches do |batch|
      batch.each do |possibly_affected_occurrence|
        occurrences << possibly_affected_occurrence
      end
    end
    occurrences
  end

  context 'when the component purl_type is for dependency scanning' do
    let_it_be(:matching_occurrences) do
      create_list(:sbom_occurrence, 3, component: matching_component, project: project)
    end

    let_it_be(:non_matching_occurrences) do
      create_list(:sbom_occurrence, 3, component: non_matching_component, project: project)
    end

    let_it_be(:package_name) { matching_component.name }
    let_it_be(:purl_type) { matching_component.purl_type }

    it_behaves_like 'non-matching component'
    it_behaves_like 'matching component'

    context 'with pypi-related package names' do
      let_it_be(:purl_type) { 'pypi' }
      let_it_be(:package_name) { 'Matching_package' }
      let_it_be(:normalized_name) do
        ::Sbom::PackageUrl::Normalizer.new(type: purl_type, text: package_name).normalize_name
      end

      let_it_be(:matching_component) { create(:sbom_component, name: normalized_name, purl_type: purl_type) }

      let_it_be(:matching_occurrences) do
        create_list(:sbom_occurrence, 3, component: matching_component, project: project)
      end

      it 'returns the possibly affected occurrences' do
        expect(possibly_affected_occurrences).to match_array(matching_occurrences)
      end
    end
  end

  context 'when the component purl_type is for container scanning' do
    let_it_be(:matching_occurrences) do
      create_list(:sbom_occurrence, 3, source_package: matching_source_package, project: project)
    end

    let_it_be(:non_matching_occurrences) do
      create_list(:sbom_occurrence, 3, source_package: non_matching_source_package, project: project)
    end

    let_it_be(:package_name) { matching_source_package.name }
    let_it_be(:purl_type) { matching_source_package.purl_type }

    it_behaves_like 'non-matching component'
    it_behaves_like 'matching component'
  end
end
