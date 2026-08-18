# frozen_string_literal: true

require "spec_helper"

RSpec.describe SCA::LicenseCompliance, feature_category: :software_composition_analysis, factory_default: :keep do
  let(:license_compliance) { described_class.new(project, pipeline, target_branch) }
  let_it_be(:mit_spdx_identifier) { 'MIT' }
  let_it_be(:mit_name) { 'MIT License' }
  let_it_be(:project) { create_default(:project, :repository, :private) }
  let_it_be(:security_orchestration_policy_configuration) { create_default(:security_orchestration_policy_configuration, project: project) }
  let_it_be(:security_policy) { create_default(:security_policy, security_orchestration_policy_configuration: security_orchestration_policy_configuration) }
  let_it_be(:merge_request) { create(:merge_request) }
  let(:target_branch) { merge_request.target_branch }
  let_it_be(:bsd_3_spdx_identifier) { 'BSD-3-Clause' }
  let_it_be(:bsd_3_name) { 'BSD 3-Clause "New" or "Revised" License' }

  before_all do
    create(:pm_package, name: "activesupport", purl_type: "gem",
      other_licenses: [{ license_names: ["MIT"], versions: ["5.1.4"] }])
    create(:pm_package, name: "github.com/sirupsen/logrus", purl_type: "golang",
      other_licenses: [{ license_names: ["MIT", "BSD-3-Clause"], versions: ["v1.4.2"] }])
    create(:pm_package, name: "org.apache.logging.log4j/log4j-api", purl_type: "maven",
      other_licenses: [{ license_names: ["BSD-3-Clause"], versions: ["2.6.1"] }])
  end

  before do
    stub_licensed_features(license_scanning: true)
  end

  describe "#policies" do
    context 'when license policies are configured with scan result policies' do
      subject(:policies) { license_compliance.policies }

      let(:pipeline) { create(:ci_pipeline, :success, project: project, builds: []) }

      let(:license_check_and_scan_result_policies) do
        [
          { id: 'MIT', name: 'MIT', classification: 'allowed', approval_policy: false },
          { id: 'AML', name: 'Apple MIT License', classification: 'denied', approval_policy: false },
          { id: 'MS-PL', name: 'Microsoft Public License', classification: 'denied', approval_policy: true },
          { id: 'Apache-2.0', name: 'Apache-2.0 License', classification: 'allowed', approval_policy: true }
        ]
      end

      let(:denied_scan_result_policies) do
        [
          { id: 'MIT', name: 'MIT', classification: 'allowed', approval_policy: false },
          { id: 'AML', name: 'Apple MIT License', classification: 'denied', approval_policy: false },
          { id: 'MS-PL', name: 'Microsoft Public License', classification: 'denied', approval_policy: true }
        ]
      end

      let(:only_license_check_policies) do
        [
          { id: 'MIT', name: 'MIT', classification: 'allowed', approval_policy: false },
          { id: 'AML', name: 'Apple MIT License', classification: 'denied', approval_policy: false }
        ]
      end

      let(:only_scan_result_policies) do
        [
          { id: 'Apache-2.0', name: 'Apache-2.0 License', classification: 'allowed', approval_policy: true },
          { id: 'MS-PL', name: 'Microsoft Public License', classification: 'denied', approval_policy: true }
        ]
      end

      using RSpec::Parameterized::TableSyntax

      where(:input, :result) do
        ref(:license_check_and_scan_result_policies) | %w[denied allowed denied allowed denied denied]
        ref(:denied_scan_result_policies) | %w[denied unclassified unclassified allowed denied unclassified]
        ref(:only_license_check_policies) | %w[denied unclassified unclassified allowed unclassified unclassified]
        ref(:only_scan_result_policies) | %w[denied allowed denied denied denied denied]
      end

      with_them do
        let(:report) { create(:ci_reports_license_scanning_report) }

        before do
          report.add_license(id: 'MIT', name: 'MIT License')
          report.add_license(id: 'AML', name: 'Apple MIT License')
          report.add_license(id: 'MS-PL', name: 'Microsoft Public License')
          report.add_license(id: 'Apache-2.0', name: 'Apache-2.0 License')
          report.add_license(id: 'GPL-3-Clause', name: 'GPL-3-Clause')
          report.add_license(id: 'unknown', name: 'unknown')

          allow(license_compliance).to receive(:license_scanning_report).and_return(report)

          input.each do |policy|
            scan_result_policy_read = policy[:approval_policy] ? create(:scan_result_policy_read, match_on_inclusion_license: policy[:classification] == 'denied') : nil
            create(:software_license_policy, policy[:classification],
              project: project,
              software_license_spdx_identifier: policy[:id],
              scan_result_policy_read: scan_result_policy_read
            )
          end
        end

        it 'sets classification based on policies' do
          expect(policies.map(&:classification)).to eq(result)
        end
      end
    end

    context "with cyclonedx report" do
      subject(:policies) { license_compliance.policies }

      context "when a pipeline has not been run for this project" do
        let(:pipeline) { nil }

        it { expect(policies.count).to be_zero }

        context "when the project has policies configured" do
          let!(:mit_policy) { create(:software_license_policy, :denied, software_license_spdx_identifier: mit_spdx_identifier, project: project) }

          it "includes an a policy for a classified license that was not detected in the scan report" do
            expect(policies.count).to eq(1)
            expect(policies[0].id).to eq(mit_policy.id)
            expect(policies[0].name).to eq(mit_name)
            expect(policies[0].url).to be_blank
            expect(policies[0].classification).to eq("denied")
            expect(policies[0].spdx_identifier).to eq(mit_spdx_identifier)
          end

          context "when the target branch is not available" do
            let(:target_branch) { nil }

            it "reports the license as allowed" do
              expect(policies.count).to eq(1)
              expect(policies[0].id).to eq(mit_policy.id)
              expect(policies[0].name).to eq(mit_name)
              expect(policies[0].url).to be_blank
              expect(policies[0].classification).to eq("allowed")
              expect(policies[0].spdx_identifier).to eq(mit_spdx_identifier)
            end
          end

          context "when the policy does not applies to the target branch" do
            before do
              mit_policy.approval_policy_rule.update!(
                content: mit_policy.approval_policy_rule.content.merge('branches' => ['main'])
              )
            end

            let(:target_branch) { 'non-main-branch' }

            it "reports the license as allowed" do
              expect(policies.count).to eq(1)
              expect(policies[0].id).to eq(mit_policy.id)
              expect(policies[0].name).to eq(mit_name)
              expect(policies[0].url).to be_blank
              expect(policies[0].classification).to eq("allowed")
              expect(policies[0].spdx_identifier).to eq(mit_spdx_identifier)
            end
          end
        end
      end

      context "when a pipeline has run" do
        let(:pipeline) { create(:ci_pipeline, :success, project: project, builds: builds) }
        let(:builds) { [] }

        context "when a license scan job is not configured" do
          let(:builds) { [create(:ci_build, :success)] }

          it { expect(policies).to be_empty }
        end

        context "when the license scan job has not finished" do
          let(:builds) { [create(:ee_ci_build, :running, job_artifacts: [artifact])] }
          # Creating the artifact manually skips the artifact upload step and simulates
          # a pending artifact upload.
          let(:artifact) { create(:ee_ci_job_artifact, file_type: :cyclonedx, file_format: :gzip) }

          it { expect(policies).to be_empty }
        end

        context "when a pipeline has successfully produced a cyclonedx report" do
          let(:builds) { [create(:ee_ci_build, :cyclonedx)] }

          let!(:mit_policy) { create(:software_license_policy, :denied, software_license_spdx_identifier: mit_spdx_identifier, project: project) }
          let!(:other_license_policy) do
            create(:software_license_policy, :allowed,
              custom_software_license: create(:custom_software_license, name: 'SOFTWARE-LICENSE'),
              software_license_spdx_identifier: nil, project: project)
          end

          it 'includes a policy for each detected license and classified license' do
            expect(policies.count).to eq(4)
          end

          it 'includes a policy for a detected license that is unclassified' do
            expect(policies[0].id).to be_nil
            expect(policies[0].name).to eq('BSD 3-Clause "New" or "Revised" License')
            expect(policies[0].url).to eq('https://spdx.org/licenses/BSD-3-Clause.html')
            expect(policies[0].classification).to eq('unclassified')
            expect(policies[0].spdx_identifier).to eq('BSD-3-Clause')
          end

          it 'includes a policy for a classified license that was also detected in the scan report' do
            expect(policies[1].id).to eq(mit_policy.id)
            expect(policies[1].name).to eq(mit_name)
            expect(policies[1].url).to eq('https://spdx.org/licenses/MIT.html')
            expect(policies[1].classification).to eq('denied')
            expect(policies[1].spdx_identifier).to eq('MIT')
          end

          it 'includes a policy for an unclassified and unknown license that was detected in the scan report' do
            expect(policies[3].id).to be_nil
            expect(policies[3].name).to eq('unknown')
            expect(policies[3].url).to be_blank
            expect(policies[3].classification).to eq('unclassified')
            expect(policies[3].spdx_identifier).to be_nil
          end
        end
      end
    end
  end

  describe "#find_policies" do
    def assert_matches(item, expected = {})
      actual = expected.keys.index_with do |attribute|
        item.public_send(attribute)
      end
      expect(actual).to eql(expected)
    end

    context "with license_scanning report" do
      let!(:pipeline) { create(:ci_pipeline, :success, project: project, builds: [create(:ee_ci_build, :success, :license_scan_v2_1)]) }
      let!(:mit_policy) { create(:software_license_policy, :denied, software_license_spdx_identifier: mit_spdx_identifier, project: project) }
      let!(:other_license_policy) { create(:software_license_policy, :allowed, custom_software_license: create(:custom_software_license, name: 'SOFTWARE-LICENSE'), software_license_spdx_identifier: nil, project: project) }
      let(:results) { license_compliance.find_policies(detected_only: true) }

      it 'does not process the report' do
        expect(results).to be_empty
      end
    end

    context "with cyclonedx report" do
      let!(:pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }
      let!(:mit_policy) { create(:software_license_policy, :denied, software_license_spdx_identifier: mit_spdx_identifier, project: project) }
      let!(:other_license_policy) { create(:software_license_policy, :allowed, software_license_spdx_identifier: bsd_3_spdx_identifier, project: project) }

      before do
        create(:pm_package, name: "nokogiri", purl_type: "gem",
          other_licenses: [{ license_names: ["CUSTOM_DENIED_LICENSE"], versions: ["1.8.0"] }])
      end

      it 'records an onboarding progress action for license scanning' do
        expect(::Onboarding::Progress).to receive(:register).with(pipeline.project.root_namespace, :license_scanning_run).and_call_original

        license_compliance.find_policies
      end

      context 'when pipeline is not present' do
        let!(:pipeline) { nil }

        it 'records an onboarding progress action for license scanning' do
          expect(::Onboarding::Progress).not_to receive(:register).with(anything)

          license_compliance.find_policies
        end
      end

      context 'when searching for policies for licenses that were detected in a scan report' do
        let(:results) { license_compliance.find_policies(detected_only: true) }

        it 'only includes licenses that appear in the latest license scan report' do
          expect(results.count).to eq(4)
        end

        it 'includes a policy for an allowed known license that was detected in the scan report' do
          assert_matches(
            results[0],
            id: other_license_policy.id,
            name: bsd_3_name,
            url: 'https://spdx.org/licenses/BSD-3-Clause.html',
            classification: 'allowed',
            spdx_identifier: bsd_3_spdx_identifier
          )
        end

        it 'includes an entry for an unclassified custom license found in the scan report' do
          assert_matches(
            results[1],
            id: nil,
            name: "CUSTOM_DENIED_LICENSE",
            url: "https://spdx.org/licenses/CUSTOM_DENIED_LICENSE.html",
            classification: "unclassified",
            spdx_identifier: "CUSTOM_DENIED_LICENSE"
          )
        end

        it 'includes an entry for a denied license found in the scan report' do
          assert_matches(
            results[2],
            id: mit_policy.id,
            name: mit_name,
            url: 'https://spdx.org/licenses/MIT.html',
            classification: 'denied',
            spdx_identifier: mit_spdx_identifier
          )
        end

        it 'includes an entry for an unclassified unknown license found in the scan report' do
          assert_matches(
            results[3],
            id: nil,
            name: 'unknown',
            url: nil,
            classification: 'unclassified',
            spdx_identifier: nil
          )
        end

        context "with denied license without spdx identifier" do
          let!(:pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }
          let_it_be(:custom_denied_license) { create(:custom_software_license, name: 'CUSTOM_DENIED_LICENSE') }
          let!(:custom_license_policy) do
            create(:software_license_policy, :denied, custom_software_license: custom_denied_license,
              software_license_spdx_identifier: nil, project: project)
          end

          let(:results) { license_compliance.find_policies(detected_only: true) }

          it 'contains denied license' do
            expect(results.count).to eq(4)
          end
        end
      end

      context "when searching for policies with a specific classification" do
        let(:results) { license_compliance.find_policies(classification: ['allowed']) }

        it 'includes an entry for each `allowed` licensed' do
          expect(results.count).to eq(1)
          assert_matches(
            results[0],
            id: other_license_policy.id,
            name: bsd_3_name,
            url: 'https://spdx.org/licenses/BSD-3-Clause.html',
            classification: 'allowed',
            spdx_identifier: bsd_3_spdx_identifier
          )
        end
      end

      context "when searching for policies by multiple classifications" do
        let(:results) { license_compliance.find_policies(classification: %w[allowed denied]) }

        it 'includes an entry for each `allowed` and `denied` licensed' do
          expect(results.count).to eq(2)
          assert_matches(
            results[0],
            id: other_license_policy.id,
            name: bsd_3_name,
            url: 'https://spdx.org/licenses/BSD-3-Clause.html',
            classification: 'allowed',
            spdx_identifier: bsd_3_spdx_identifier
          )
          assert_matches(
            results[1],
            id: mit_policy.id,
            name: mit_name,
            url: 'https://spdx.org/licenses/MIT.html',
            classification: 'denied',
            spdx_identifier: mit_spdx_identifier
          )
        end
      end

      context "when searching for detected policies matching a classification" do
        let(:results) { license_compliance.find_policies(detected_only: true, classification: %w[allowed denied]) }

        it 'includes an entry for each entry that was detected in the report and matches a classification' do
          expect(results.count).to eq(2)
          assert_matches(
            results[0],
            id: other_license_policy.id,
            name: bsd_3_name,
            url: 'https://spdx.org/licenses/BSD-3-Clause.html',
            classification: 'allowed',
            spdx_identifier: bsd_3_spdx_identifier
          )
          assert_matches(
            results[1],
            id: mit_policy.id,
            name: mit_name,
            url: 'https://spdx.org/licenses/MIT.html',
            classification: 'denied',
            spdx_identifier: mit_spdx_identifier
          )
        end
      end

      context 'when sorting policies' do
        let(:sorted_by_name_asc) { ['BSD 3-Clause "New" or "Revised" License', 'CUSTOM_DENIED_LICENSE', 'MIT License', 'unknown'] }

        where(:attribute, :direction, :expected) do
          sorted_by_name_asc = ['BSD 3-Clause "New" or "Revised" License', 'CUSTOM_DENIED_LICENSE', 'MIT License', 'unknown']
          sorted_by_classification_asc = ['BSD 3-Clause "New" or "Revised" License', 'CUSTOM_DENIED_LICENSE', 'unknown', 'MIT License']
          [
            [:classification, :asc, sorted_by_classification_asc],
            [:classification, :desc, sorted_by_classification_asc.reverse],
            [:name, :desc, sorted_by_name_asc.reverse],
            [:invalid, :asc, sorted_by_name_asc],
            [:name, :invalid, sorted_by_name_asc],
            [:name, nil, sorted_by_name_asc],
            [nil, :asc, sorted_by_name_asc],
            [nil, nil, sorted_by_name_asc]
          ]
        end

        with_them do
          let(:results) { license_compliance.find_policies(sort: { by: attribute, direction: direction }) }

          it { expect(results.map(&:name)).to eq(expected) }
        end

        context 'when using the default sort options' do
          it { expect(license_compliance.find_policies.map(&:name)).to eq(sorted_by_name_asc) }
        end

        context 'when `nil` sort options are provided' do
          it { expect(license_compliance.find_policies(sort: nil).map(&:name)).to eq(sorted_by_name_asc) }
        end
      end
    end
  end

  describe "#latest_build_for_default_branch" do
    subject { license_compliance.latest_build_for_default_branch }

    let(:pipeline) { nil }
    let(:regular_build) { create(:ci_build, :success) }
    let(:license_scan_build) { create(:ee_ci_build, :cyclonedx, :success) }

    context "when a pipeline has never been completed for the project" do
      let(:pipeline) { nil }

      it { is_expected.to be_nil }
    end

    context "when a pipeline has completed successfully and produced a license scan report" do
      let!(:pipeline) { create(:ee_ci_pipeline, :success, project: project, builds: [regular_build, license_scan_build]) }

      it { is_expected.to eq(license_scan_build) }
    end

    context "when a pipeline has completed but does not contain a license scan report" do
      let!(:pipeline) { create(:ci_pipeline, :success, project: project, builds: [regular_build]) }

      it { is_expected.to be_nil }
    end
  end

  describe "#diff_with" do
    context 'when license policies are configured with scan result policies' do
      subject(:diff) { license_compliance.diff_with(base_compliance) }

      let(:aml_spdx_identifier) { 'AML' }
      let(:mspl_spdx_identifier) { 'MS-PL' }

      let(:pipeline) { create(:ci_pipeline, :success, project: project, builds: []) }
      let(:base_pipeline) { create(:ci_pipeline, :success, project: project) }
      let(:base_compliance) { project.license_compliance(base_pipeline) }

      let(:base_report) { create(:ci_reports_license_scanning_report) }
      let(:report) { create(:ci_reports_license_scanning_report) }

      let(:scan_result_policy_read_with_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: true) }
      let(:scan_result_policy_read_without_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: false) }

      context 'when base_report has new denied licenses' do
        before do
          report.add_license(id: 'MIT', name: 'MIT')
          base_report.add_license(id: 'MIT', name: 'MIT')
          base_report.add_license(id: 'AML', name: 'Apple MIT License')
          base_report.add_license(id: 'MS-PL', name: 'Microsoft Public License')

          allow(license_compliance).to receive(:license_scanning_report).and_return(report)
          allow(base_compliance).to receive(:license_scanning_report).and_return(base_report)

          create(:software_license_policy, :allowed,
            project: project,
            software_license_spdx_identifier: mit_spdx_identifier,
            scan_result_policy_read: scan_result_policy_read_without_inclusion
          )
          create(:software_license_policy, :denied,
            project: project,
            software_license_spdx_identifier: aml_spdx_identifier,
            scan_result_policy_read: scan_result_policy_read_with_inclusion
          )
        end

        it 'returns differences with denied status' do
          added = diff[:added]

          expect(added[0].spdx_identifier).to eq(aml_spdx_identifier)
          expect(added[0].classification).to eq('denied')
          expect(added[1].spdx_identifier).to eq(mspl_spdx_identifier)
          expect(added[1].classification).to eq('denied')
        end

        context 'when base_report has new denied custom licenses' do
          let(:custom_license) { create(:custom_software_license, name: 'Custom License') }

          before do
            base_report.add_license(id: nil, name: 'Custom License')

            create(:software_license_policy, :denied,
              project: project,
              software_license_spdx_identifier: nil,
              custom_software_license: custom_license,
              scan_result_policy_read: create(:scan_result_policy_read, match_on_inclusion_license: true)
            )
          end

          it 'returns differences with denied status' do
            added = diff[:added]
            expect(added[0].spdx_identifier).to eq(aml_spdx_identifier)
            expect(added[0].classification).to eq('denied')
            expect(added[1].name).to eq(custom_license.name)
            expect(added[1].classification).to eq('denied')
            expect(added[2].spdx_identifier).to eq(mspl_spdx_identifier)
            expect(added[2].classification).to eq('denied')
          end
        end

        context 'when the project contains a software license with an unknown spdx id' do
          let!(:software_license_policy_non_spdx_id) do
            create(:software_license_policy, :denied,
              project: project,
              software_license_spdx_identifier: 'non-spdx-identifier',
              scan_result_policy_read: create(:scan_result_policy_read, match_on_inclusion_license: true)
            )
          end

          it 'tracks the missing license' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              kind_of(described_class::LicenseNotFoundError), license_spdx_id: software_license_policy_non_spdx_id.software_license_spdx_identifier,
              project_id: software_license_policy_non_spdx_id.project_id
            )

            diff
          end

          it 'returns differences with denied status' do
            added = diff[:added]

            expect(added[0].spdx_identifier).to eq(aml_spdx_identifier)
            expect(added[0].classification).to eq('denied')
            expect(added[1].spdx_identifier).to eq(mspl_spdx_identifier)
            expect(added[1].classification).to eq('denied')
          end
        end
      end

      context 'when when base_report has new dependencies for the same denied license' do
        before do
          report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'Old dependency')
          base_report.add_license(id: 'MIT', name: 'MIT').add_dependency(name: 'New dependency')

          allow(license_compliance).to receive(:license_scanning_report).and_return(report)
          allow(base_compliance).to receive(:license_scanning_report).and_return(base_report)

          create(:software_license_policy, :denied,
            project: project,
            software_license_spdx_identifier: mit_spdx_identifier,
            scan_result_policy_read: scan_result_policy_read_without_inclusion
          )
        end

        it 'returns differences with denied status' do
          added = diff[:added]

          expect(added[0].spdx_identifier).to eq('MIT')
          expect(added[0].classification).to eq('denied')
        end
      end

      context 'when base_report does not have denied licenses' do
        before do
          base_report.add_license(id: mit_spdx_identifier, name: mit_name)

          allow(license_compliance).to receive(:license_scanning_report).and_return(report)
          allow(base_compliance).to receive(:license_scanning_report).and_return(base_report)

          create(:software_license_policy, :allowed,
            project: project,
            software_license_spdx_identifier: mit_spdx_identifier,
            scan_result_policy_read: scan_result_policy_read_without_inclusion
          )
        end

        it 'returns differences with allowed status' do
          added = diff[:added]

          expect(added[0].spdx_identifier).to eq(mit_spdx_identifier)
          expect(added[0].classification).to eq('allowed')
        end
      end
    end

    context "when the head pipeline has not run" do
      subject(:diff) { license_compliance.diff_with(base_compliance) }

      let(:pipeline) { nil }

      let!(:base_compliance) { project.license_compliance(base_pipeline) }
      let!(:base_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

      it "returns the differences in licenses introduced by the merge request" do
        expect(diff[:added]).to all(be_instance_of(::SCA::LicensePolicy))
        expect(diff[:added].count).to eq(3)
        expect(diff[:removed]).to be_empty
        expect(diff[:unchanged]).to be_empty
      end
    end

    context "when nothing has changed between the head and the base pipeline" do
      subject(:diff) { license_compliance.diff_with(base_compliance) }

      let(:pipeline) { head_pipeline }

      let!(:head_compliance) { project.license_compliance(head_pipeline) }
      let!(:head_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

      let!(:base_compliance) { project.license_compliance(base_pipeline) }
      let!(:base_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

      it "returns the differences in licenses introduced by the merge request" do
        expect(diff[:added]).to be_empty
        expect(diff[:removed]).to be_empty
        expect(diff[:unchanged]).to all(be_instance_of(::SCA::LicensePolicy))
        expect(diff[:unchanged].count).to eq(3)
      end
    end

    context "when the base pipeline removed some licenses" do
      subject(:diff) { license_compliance.diff_with(base_compliance) }

      let(:pipeline) { head_pipeline }

      let!(:head_compliance) { project.license_compliance(head_pipeline) }
      let!(:head_pipeline) { create(:ee_ci_pipeline, :with_cyclonedx_report, project: project) }

      let!(:base_compliance) { project.license_compliance(base_pipeline) }
      let!(:base_pipeline) { create(:ee_ci_pipeline, :success, project: project, builds: [create(:ee_ci_build, :success)]) }

      it "returns the differences in licenses introduced by the merge request" do
        expect(diff[:added]).to be_empty
        expect(diff[:unchanged]).to be_empty
        expect(diff[:removed]).to all(be_instance_of(::SCA::LicensePolicy))
        expect(diff[:removed].count).to eq(3)
      end
    end

    context "when the base pipeline added some licenses" do
      subject(:diff) { license_compliance.diff_with(base_compliance) }

      let(:pipeline) { head_pipeline }

      let!(:head_compliance) { project.license_compliance(head_pipeline) }
      let!(:head_pipeline) { create(:ee_ci_pipeline, :success, project: project, builds: [create(:ee_ci_build, :success)]) }

      let!(:base_compliance) { project.license_compliance(base_pipeline) }
      let!(:base_pipeline) { create(:ee_ci_pipeline, :success, project: project, builds: [create(:ee_ci_build, :cyclonedx, :success)]) }

      it "returns the differences in licenses introduced by the merge request" do
        expect(diff[:added]).to all(be_instance_of(::SCA::LicensePolicy))
        expect(diff[:added].count).to eq(3)
        expect(diff[:removed]).to be_empty
        expect(diff[:unchanged]).to be_empty
      end

      context "when a software license record does not have an spdx identifier" do
        let(:license_name) { mit_name }
        let!(:policy) { create(:software_license_policy, :allowed, project: project, software_license_spdx_identifier: mit_spdx_identifier) }

        it "falls back to matching detections based on name rather than spdx id" do
          mit = diff[:added].find { |item| item.name == license_name }

          expect(mit).to be_present
          expect(mit.classification).to eql('allowed')
        end
      end
    end
  end
end
