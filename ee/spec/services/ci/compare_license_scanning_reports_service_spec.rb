# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CompareLicenseScanningReportsService, feature_category: :software_composition_analysis do
  include ProjectForksHelper

  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:ee_merge_request, :with_dependency_scanning_reports, source_project: project) }
  let_it_be(:target_branch) { merge_request.target_branch }

  let(:service) { described_class.new(project, nil, id: merge_request.id) }

  before do
    stub_licensed_features(license_scanning: true)
  end

  describe '#execute' do
    subject { service.execute(base_pipeline, head_pipeline) }

    context "when loading data for multiple reports" do
      it 'loads the data efficiently' do
        base_pipeline = create(:ee_ci_pipeline, project: project)
        head_pipeline = create(:ee_ci_pipeline, :with_cyclonedx_report, project: project)

        control = ActiveRecord::QueryRecorder.new do
          service.execute(base_pipeline.reload, head_pipeline.reload)
        end

        new_head_pipeline = create(:ee_ci_pipeline, :with_cyclonedx_report, project: project)

        expect do
          service.execute(base_pipeline.reload, new_head_pipeline.reload)
        end.not_to exceed_query_limit(control)
      end
    end

    shared_examples_for 'invokes the SCA::LicenseCompliance using the pipeline\'s project' do
      it 'invokes the SCA::LicenseCompliance using the pipeline\'s project' do
        expect(::SCA::LicenseCompliance).to receive(:new).with(base_pipeline.project, base_pipeline, target_branch).and_call_original
        expect(::SCA::LicenseCompliance).to receive(:new).with(head_pipeline.project, head_pipeline, target_branch).and_call_original

        service.execute(base_pipeline, head_pipeline)
      end
    end

    shared_examples_for 'fallback to the service class project instance variable to invoke the SCA::LicenseCompliance' do
      it 'fallback to the service class project instance variable to invoke the SCA::LicenseCompliance' do
        expect(::SCA::LicenseCompliance).to receive(:new).with(project, base_pipeline, target_branch).and_call_original
        expect(::SCA::LicenseCompliance).to receive(:new).with(head_pipeline.project, head_pipeline, target_branch).and_call_original

        service.execute(base_pipeline, head_pipeline)
      end
    end

    context 'when head pipeline has test reports' do
      context 'with incorrect report type' do
        let_it_be(:base_pipeline) { nil }
        let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :with_license_scanning_report, project: project) }

        it 'reports new licenses' do
          expect(subject[:status]).to eq(:parsed)
          expect(subject[:data]['new_licenses']).to be_empty
          expect(subject[:data]['existing_licenses']).to be_empty
          expect(subject[:data]['removed_licenses']).to be_empty
        end

        it_behaves_like 'fallback to the service class project instance variable to invoke the SCA::LicenseCompliance'
      end

      context 'with cyclonedx report' do
        let_it_be(:base_pipeline) { nil }
        let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

        before_all do
          create(:pm_package, name: "nokogiri", purl_type: "gem",
            other_licenses: [{ license_names: ["BSD-4-Clause"], versions: ["1.8.0"] }])
        end

        it 'reports new licenses' do
          expect(subject[:status]).to eq(:parsed)
          expect(subject[:data]['new_licenses']).to match_array([a_hash_including('name' => 'BSD 4-Clause "Original" or "Old" License'),
            a_hash_including('name' => 'unknown')])
        end

        it 'reports new licenses statuses' do
          expect(subject[:data]['new_licenses'][0]['classification']['approval_status']).to eq('unclassified')
        end

        it_behaves_like 'fallback to the service class project instance variable to invoke the SCA::LicenseCompliance'
      end
    end

    context 'when base pipeline does not have test reports' do
      let_it_be(:maintainer) { create(:user) }
      let_it_be(:contributor) { create(:user) }
      let_it_be(:project) { create(:project, :public, :repository, maintainers: maintainer, developers: contributor) }
      let_it_be(:merge_request) { create(:ee_merge_request, :with_dependency_scanning_reports, source_project: project) }
      let(:service) { described_class.new(project, maintainer, id: merge_request.id) }
      let(:head_pipeline_project) { project }
      let(:head_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: head_pipeline_project, user: contributor) }

      before_all do
        create(:pm_package, name: 'nokogiri', purl_type: 'gem',
          other_licenses: [{ license_names: ['BSD-4-Clause'], versions: ['1.8.0'] }])
      end

      shared_examples 'reports new licenses' do
        it 'reports new licenses' do
          expect(subject[:status]).to eq(:parsed)
          expect(subject[:data]['new_licenses'].count).to eq(2)
        end

        it 'reports new licenses statuses' do
          expect(subject[:data]['new_licenses'][0]['classification']['approval_status']).to eq('unclassified')
          expect(subject[:data]['new_licenses'][1]['classification']['approval_status']).to eq('unclassified')
        end
      end

      context 'when base pipeline has not run' do
        let(:base_pipeline) { nil }

        it_behaves_like 'reports new licenses'
        it_behaves_like 'fallback to the service class project instance variable to invoke the SCA::LicenseCompliance'
      end

      context 'when base pipeline has not run and head pipeline is for a forked project' do
        let(:base_pipeline) { nil }
        let(:forked_project) { fork_project(project, contributor, namespace: contributor.namespace) }
        let(:head_pipeline_project) { forked_project }

        it_behaves_like 'reports new licenses'
        it_behaves_like 'fallback to the service class project instance variable to invoke the SCA::LicenseCompliance'
      end

      context 'when base pipeline does not have a license scanning report' do
        let_it_be(:base_pipeline) { create(:ee_ci_pipeline, project: project) }

        it_behaves_like 'reports new licenses'
        it_behaves_like 'invokes the SCA::LicenseCompliance using the pipeline\'s project'
      end
    end

    context 'when base and head pipelines have test reports' do
      context 'with license scanning reports' do
        let_it_be(:base_pipeline) { create(:ee_ci_pipeline, :with_license_scanning_report, project: project) }
        let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :with_license_scanning_feature_branch, project: project) }

        it 'reports status as parsed' do
          expect(subject[:status]).to eq(:parsed)
        end

        it 'does not display results' do
          expect(subject[:data]['new_licenses']).to be_empty
          expect(subject[:data]['existing_licenses']).to be_empty
          expect(subject[:data]['removed_licenses']).to be_empty
        end

        it_behaves_like 'invokes the SCA::LicenseCompliance using the pipeline\'s project'
      end

      context 'with cyclonedx reports' do
        let_it_be(:base_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }
        let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_pypi_only, project: project) }

        before_all do
          create(:pm_package, name: "nokogiri", purl_type: "gem",
            other_licenses: [{ license_names: %w[BSD-4-Clause MIT], versions: ["1.8.0"] }])

          create(:pm_package, name: "django", purl_type: "pypi",
            other_licenses: [{ license_names: ["BSD-4-Clause", "Apache-2.0"], versions: ["1.11.4"] }])
        end

        it 'reports status as parsed' do
          expect(subject[:status]).to eq(:parsed)
        end

        it 'reports new licenses' do
          expect(subject[:data]['new_licenses']).to match([a_hash_including('name' => 'Apache License 2.0'),
            a_hash_including('name' => 'BSD 4-Clause "Original" or "Old" License'),
            a_hash_including('name' => 'unknown')])
        end

        it 'reports new licenses statuses' do
          expect(subject[:data]['new_licenses'][0]['classification']['approval_status']).to eq('unclassified')
        end

        it 'reports existing licenses' do
          expect(subject[:data]['existing_licenses']).to match(
            [a_hash_including('name' => 'BSD 4-Clause "Original" or "Old" License'), a_hash_including('name' => 'unknown')]
          )
        end

        it 'reports existing licenses statuses' do
          expect(subject[:data]['existing_licenses'][0]['classification']['approval_status']).to eq('unclassified')
        end

        it 'reports removed licenses' do
          expect(subject[:data]['removed_licenses']).to match([a_hash_including('name' => 'MIT License')])
        end

        it_behaves_like 'invokes the SCA::LicenseCompliance using the pipeline\'s project'
      end
    end

    context 'when pipelines have corrupted reports' do
      let_it_be(:base_pipeline) { build(:ee_ci_pipeline, :with_corrupted_cyclonedx_report, project: project) }
      let_it_be(:head_pipeline) { build(:ee_ci_pipeline, :with_corrupted_cyclonedx_report, project: project) }

      context "when base and head pipeline have corrupted reports" do
        it 'does not expose parser errors' do
          expect(subject[:status]).to eq(:parsed)
        end
      end

      context "when the base pipeline is nil" do
        subject { service.execute(nil, head_pipeline) }

        it 'does not expose parser errors' do
          expect(subject[:status]).to eq(:parsed)
        end
      end

      it_behaves_like 'invokes the SCA::LicenseCompliance using the pipeline\'s project'
    end

    describe 'approval_required and has_denied_licenses', :aggregate_failures do
      let_it_be(:base_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }
      let_it_be(:head_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_pypi_only, project: project) }

      before_all do
        create(:pm_package, name: "nokogiri", purl_type: "gem",
          other_licenses: [{ license_names: ["BSD-3-Clause"], versions: ["1.8.0"] }])
        create(:pm_package, name: "django", purl_type: "pypi",
          other_licenses: [{ license_names: ["MIT"], versions: ["1.11.4"] }])
      end

      context 'when merge request id is not provided' do
        let(:service) { described_class.new(project, nil) }

        it 'exposes approval_required and has_denied_licenses as false' do
          expect(subject[:data]['approval_required']).to be(false)
          expect(subject[:data]['has_denied_licenses']).to be(false)
        end
      end

      context 'when merge request is not found' do
        let(:service) { described_class.new(project, nil, id: non_existing_record_id) }

        it 'exposes approval_required and has_denied_licenses as false' do
          expect(subject[:data]['approval_required']).to be(false)
          expect(subject[:data]['has_denied_licenses']).to be(false)
        end
      end

      context 'without denied licenses' do
        it 'exposes approval_required and has_denied_licenses as false' do
          expect(subject[:data]['approval_required']).to be(false)
          expect(subject[:data]['has_denied_licenses']).to be(false)
        end
      end

      context 'with denied licenses' do
        before do
          allow_next_instance_of(::SCA::LicensePolicy) do |license|
            allow(license).to receive(:approval_status).and_return('denied')
          end
        end

        it 'exposes has_denied_licenses as true and approval_required as false' do
          expect(subject[:data]['has_denied_licenses']).to be(true)
          expect(subject[:data]['approval_required']).to be(false)
        end

        context 'with license_check approval rule' do
          let_it_be(:license_check) do
            create(:report_approver_rule, :license_scanning, merge_request: merge_request)
          end

          it 'exposes approval_required and has_denied_licenses as true' do
            expect(subject[:data]['approval_required']).to be(true)
            expect(subject[:data]['has_denied_licenses']).to be(true)
          end
        end
      end
    end
  end
end
