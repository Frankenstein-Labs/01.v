# frozen_string_literal: true

require 'spec_helper'

RSpec.describe LicenseCompliance::ComparerEntity do
  let(:entity) do
    described_class.new(
      ::Gitlab::Ci::Reports::LicenseScanning::ReportsComparer.new(
        project.license_compliance(base_pipeline),
        project.license_compliance(head_pipeline)
      ),
      request: request
    )
  end

  let_it_be(:project) { create_default(:project, :repository) }

  let_it_be(:base_pipeline) do
    create(:ci_pipeline, :success, project: project, builds: [create(:ee_ci_build, :license_scan_v2_1, :success)])
  end

  let_it_be(:head_pipeline) do
    create(:ci_pipeline, :success, project: project, builds: [create(:ee_ci_build, :success)])
  end

  let(:request) { EntityRequest.new(approval_required: false, has_denied_licenses: false) }

  describe '#as_json' do
    subject { entity.as_json }

    it 'contains the new, existing, removed license lists, approval_required and has_denied_licenses' do
      expect(subject).to have_key(:new_licenses)
      expect(subject).to have_key(:existing_licenses)
      expect(subject).to have_key(:removed_licenses)
      expect(subject).to have_key(:approval_required)
      expect(subject).to have_key(:has_denied_licenses)
    end

    context 'when approval is required and has denied licenses' do
      let(:request) { EntityRequest.new(approval_required: true, has_denied_licenses: true) }

      it 'exposes approval_required and has_denied_licenses as true' do
        expect(subject).to include(approval_required: true, has_denied_licenses: true)
      end
    end

    context 'when approval is not required and no denied licenses' do
      it 'exposes approval_required and has_denied_licenses as false' do
        expect(subject).to include(approval_required: false, has_denied_licenses: false)
      end
    end
  end
end
