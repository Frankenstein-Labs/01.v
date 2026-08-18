# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::Concerns::LicenseOverrideable, feature_category: :dependency_management do
  let(:project) { build_stubbed(:project) }

  let(:occurrence) do
    instance_double(
      ::Sbom::Occurrence,
      project: project,
      project_id: project.id,
      uuid: 'test-uuid-1234',
      purl_type: 'gem',
      component_name: 'rails',
      version: '7.0'
    )
  end

  let(:includer) do
    Class.new do
      include Types::Sbom::Concerns::LicenseOverrideable
      attr_reader :object, :context

      def initialize(object, context)
        @object = object
        @context = context
      end
    end.new(occurrence, context)
  end

  let(:license_data) do
    [
      { 'spdx_identifier' => 'MIT', 'name' => 'MIT', 'url' => nil,
        'project_id' => project.id, 'occurrence_uuid' => 'test-uuid-1234' }
    ]
  end

  let(:context) { {} }

  describe '#apply_license_overrides' do
    subject(:result) { includer.send(:apply_license_overrides, license_data) }

    shared_examples 'returns the input licenses unchanged' do
      it 'returns the input licenses unchanged' do
        expect(result).to eq(license_data)
      end
    end

    context 'when object does not respond to :project' do
      let(:occurrence) { instance_double(Object) }

      it_behaves_like 'returns the input licenses unchanged'
    end

    context 'when experiment is not enabled for the project' do
      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(false)
      end

      it_behaves_like 'returns the input licenses unchanged'
    end

    context 'when experiment is enabled but applicator has no overrides' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: false) }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new).with(project).and_return(applicator)
      end

      it_behaves_like 'returns the input licenses unchanged'
    end

    context 'when experiment is enabled and overrides are present' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:override_result) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0', 'url' => nil }] }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new).with(project).and_return(applicator)
        allow(applicator).to receive(:apply)
          .with(license_data, purl: 'pkg:gem/rails@7.0')
          .and_return(override_result)
      end

      it 'returns overridden licenses enriched with occurrence context' do
        expect(result).to contain_exactly(
          hash_including('spdx_identifier' => 'Apache-2.0', 'project_id' => project.id,
            'occurrence_uuid' => 'test-uuid-1234')
        )
      end

      context 'when the override result already has project_id set' do
        let(:override_result) do
          [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0', 'project_id' => 99 }]
        end

        it 'preserves the existing project_id' do
          expect(result.first['project_id']).to eq(99)
        end
      end
    end

    context 'when occurrence has no purl_type' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }

      before do
        allow(occurrence).to receive(:purl_type).and_return(nil)
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new).with(project).and_return(applicator)
      end

      it_behaves_like 'returns the input licenses unchanged'
    end

    context 'when occurrence has no version' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:override_result) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0', 'url' => nil }] }

      before do
        allow(occurrence).to receive(:version).and_return(nil)
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(true)
        allow(Security::LicenseOverrideApplicator).to receive(:new).with(project).and_return(applicator)
        allow(applicator).to receive(:apply)
          .with(license_data, purl: 'pkg:gem/rails')
          .and_return(override_result)
      end

      it 'builds a versionless purl and applies overrides' do
        expect(result).to contain_exactly(hash_including('spdx_identifier' => 'Apache-2.0'))
      end
    end

    context 'when the applicator is cached in context' do
      let(:applicator) { instance_double(Security::LicenseOverrideApplicator, overrides?: true) }
      let(:context) { { security_license_override_applicators: { project.id => applicator } } }
      let(:override_result) { [{ 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache-2.0', 'url' => nil }] }

      before do
        allow(Security::LicenseOverrideApplicator).to receive(:experiment_enabled_for_project?)
          .with(project).and_return(true)
        allow(applicator).to receive(:apply).and_return(override_result)
      end

      it 'uses the cached applicator without creating a new one' do
        expect(Security::LicenseOverrideApplicator).not_to receive(:new)
        includer.send(:apply_license_overrides, license_data)
      end
    end
  end
end
