# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::OccurrenceMapCollection, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:tracked_context) { create(:security_project_tracked_context, project: project) }

  let(:service_response) { ServiceResponse.success(payload: { tracked_context: tracked_context }) }

  let(:components) do
    [
      { name: "libcom-err2", version: "1.46.2-2", type: "library",
        purl: "pkg:deb/debian/libcom-err2@1.46.2-2?distro=debian-11.4",
        ref: "pkg:deb/debian/libcom-err2@1.46.2-2?distro=debian-11.4" },
      { name: "libreadline8", version: "8.1-1", type: "library",
        purl: "pkg:deb/debian/libreadline8@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/libreadline8@8.1-1?distro=debian-11.4" },
      { name: "git-man", version: "1:2.30.2-1", type: "library",
        purl: "pkg:deb/debian/git-man@1%3A2.30.2-1?distro=debian-11.4",
        ref: "pkg:deb/debian/git-man@1%3A2.30.2-1?distro=debian-11.4" },
      { name: "liblz4-1", version: "1.9.3-2", type: "library",
        purl: "pkg:deb/debian/liblz4-1@1.9.3-2?distro=debian-11.4",
        ref: "pkg:deb/debian/liblz4-1@1.9.3-2?distro=debian-11.4" },
      { name: "readline-common", version: "8.1-1", type: "library",
        purl: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4" },
      { name: "readline-common", version: nil, type: "library",
        purl: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4" },
      { name: "readline-common", version: "9.1-1", type: "library",
        purl: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4" },
      { name: "readline-common", version: "8.1-1", type: "library",
        purl: nil, ref: "ref" },
      { name: "readline-common", version: "8.1-1", type: "library",
        purl: "pkg:npm/readline-common@8.1-1", ref: "pkg:npm/readline-common@8.1-1" }
    ].map { |attributes| Gitlab::Ci::Reports::Sbom::Component.new(**component_attributes(attributes)) }
  end

  let(:sbom_report) { create(:ci_reports_sbom_report, components: components) }
  let(:expected_output) do
    [
      { name: "git-man", version: "1:2.30.2-1", type: "library",
        purl: "pkg:deb/debian/git-man@1%3A2.30.2-1?distro=debian-11.4",
        ref: "pkg:deb/debian/git-man@1%3A2.30.2-1?distro=debian-11.4" },
      { name: "libcom-err2", version: "1.46.2-2", type: "library",
        purl: "pkg:deb/debian/libcom-err2@1.46.2-2?distro=debian-11.4",
        ref: "pkg:deb/debian/libcom-err2@1.46.2-2?distro=debian-11.4" },
      { name: "liblz4-1", version: "1.9.3-2", type: "library",
        purl: "pkg:deb/debian/liblz4-1@1.9.3-2?distro=debian-11.4",
        ref: "pkg:deb/debian/liblz4-1@1.9.3-2?distro=debian-11.4" },
      { name: "libreadline8", version: "8.1-1", type: "library",
        purl: "pkg:deb/debian/libreadline8@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/libreadline8@8.1-1?distro=debian-11.4" },
      { name: "readline-common", version: "8.1-1", type: "library", purl: nil, ref: "ref" },
      { name: "readline-common", version: "8.1-1", type: "library",
        purl: "pkg:npm/readline-common@8.1-1", ref: "pkg:npm/readline-common@8.1-1" },
      { name: "readline-common", version: nil, type: "library",
        purl: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4" },
      { name: "readline-common", version: "8.1-1", type: "library",
        purl: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4" },
      { name: "readline-common", version: "9.1-1", type: "library",
        purl: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4",
        ref: "pkg:deb/debian/readline-common@8.1-1?distro=debian-11.4" }
    ].map do |attributes|
      component = Gitlab::Ci::Reports::Sbom::Component.new(**component_attributes(attributes))
      an_occurrence_map(Sbom::Ingestion::OccurrenceMap.new(component, sbom_report.source))
    end
  end

  subject(:occurrence_map_collection) { described_class.new(pipeline, sbom_report) }

  before do
    allow(::Security::ProjectTrackedContexts::FindOrCreateService).to receive(:from_pipeline).with(pipeline)
      .and_return(
        instance_double(::Security::ProjectTrackedContexts::FindOrCreateService, execute: service_response)
      )
  end

  RSpec::Matchers.define :an_occurrence_map do |expected|
    attributes = %i[
      name
      version
      component_type
      purl_type
      source
    ]

    match do |actual|
      @actual = actual.to_h.slice(*attributes)
      @expected = expected.to_h.slice(*attributes)

      @actual == @expected
    end

    diffable
  end

  shared_examples '#each' do
    it 'yields for every component in consistent order when given a block' do
      expect { |b| occurrence_map_collection.each(&b) }.to yield_successive_args(*expected_output)
    end

    context 'when not given a block' do
      let(:enumerator) { occurrence_map_collection.each }

      it 'creates an occurrence map for each occurrence in consistent order' do
        expect(enumerator.to_a).to match(expected_output)
      end
    end
  end

  describe '#each' do
    it_behaves_like '#each'

    context 'when report source is nil' do
      let(:sbom_report) { create(:ci_reports_sbom_report, source: nil, components: components) }

      it_behaves_like '#each'
    end

    it 'stamps the tracked context on every occurrence map' do
      occurrence_map_collection.each do |occurrence_map|
        expect(occurrence_map.security_project_tracked_context).to eq(tracked_context)
      end
    end

    it 'resolves the tracked context once for the whole collection' do
      occurrence_map_collection.to_a
      occurrence_map_collection.to_a

      expect(::Security::ProjectTrackedContexts::FindOrCreateService).to have_received(:from_pipeline).once
    end

    context 'when the tracked context cannot be resolved' do
      let(:service_response) { ServiceResponse.error(message: ['Some error'], payload: { tracked_context: nil }) }

      it 'raises an error' do
        expect { occurrence_map_collection.to_a }.to raise_error(
          RuntimeError, /Failed to find or create tracked context for project #{project.id}: Some error/
        )
      end
    end
  end

  def component_attributes(attributes)
    return attributes unless attributes[:purl]

    attributes[:purl] = Sbom::PackageUrl.parse(attributes[:purl])

    attributes
  end
end
