# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::Npm::ProcessTemporaryPackageFileService, feature_category: :package_registry do
  include PackagesManagerApiSpecHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { project.owner }
  let_it_be(:package_name) { FFaker::Lorem.word }
  let_it_be(:version) { '1.0.0' }

  let_it_be_with_reload(:temp_package) do
    create(:npm_package, :processing, name: package_name, version: "0.0.0-#{SecureRandom.uuid}",
      package_files: [], project: project)
  end

  let(:content) do
    fixture_file('packages/npm/payload.json')
      .gsub('@root/npm-test', package_name)
      .gsub('1.0.1', version)
  end

  let!(:file) { temp_file('payload', content:) }
  let!(:package_file) { create(:package_file, :processing, file: file, package: temp_package, file_fixture: nil) }

  let(:params) { { deprecate: false } }
  let(:firewall_service) { Security::DependencyFirewall::EnforcementService }

  describe '#execute', :aggregate_failures do
    subject(:execute) { described_class.new(package_file:, user:, params:).execute }

    before do
      stub_feature_flags(dependency_firewall_phase1: project.root_ancestor)
      allow(firewall_service).to receive(:firewall_check)
        .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))
    end

    context 'when the dependency_firewall_phase1 feature flag is disabled' do
      before do
        stub_feature_flags(dependency_firewall_phase1: false)
      end

      it 'does not call the firewall and creates the package' do
        expect(firewall_service).not_to receive(:firewall_check)

        expect(execute).to be_success
      end
    end

    context 'when the firewall allows the package' do
      it 'calls the firewall with the normalized name, version, operation, and current_user' do
        expect(firewall_service).to receive(:firewall_check)
          .with(
            project: project,
            pkg_type: 'npm',
            name: package_name,
            version: version,
            operation: firewall_service::PACKAGE_UPLOAD,
            current_user: user
          )
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_ALLOWED }))

        expect(execute).to be_success
      end
    end

    context 'when the firewall warns on the package' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.success(payload: { status: firewall_service::SUCCESS_WARNING }))
      end

      it 'creates the package' do
        expect(execute).to be_success
      end
    end

    context 'when the firewall blocks the package' do
      before do
        allow(firewall_service).to receive(:firewall_check)
          .and_return(ServiceResponse.error(message: "violates 'DF npm' policy",
            reason: firewall_service::SUCCESS_BLOCKED))
      end

      it 'returns the policy violation error and does not persist the package' do
        expect(::Packages::Npm::CreatePackageService).not_to receive(:new)

        expect(execute).to be_error.and have_attributes(
          message: "violates 'DF npm' policy",
          reason: :dependency_firewall_policy_violation
        )
      end
    end

    context 'when deprecating a package' do
      let(:params) { { deprecate: true } }
      let(:content) { fixture_file('packages/npm/deprecate_payload.json').gsub('@root/npm-test', package_name) }

      it 'does not call the firewall' do
        expect(firewall_service).not_to receive(:firewall_check)

        execute
      end
    end
  end
end
