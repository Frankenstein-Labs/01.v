# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker LicenseRef operator' do
  include_context 'for license_expression_checker'

  let(:license_ref_proprietary) { report('LicenseRef-Proprietary', 'dependency_1') }
  let(:violation_license_ref_proprietary) { violation('LicenseRef-Proprietary', 'dependency_1') }

  let(:license_ref_proprietary_lowercase) { report('LicenseRef-proprietary', 'dependency_2') }
  let(:violation_license_ref_proprietary_lowercase) { violation('LicenseRef-proprietary', 'dependency_2') }

  let(:document_ref_license_ref) { report('DocumentRef-foo:LicenseRef-bar', 'dependency_3') }
  let(:violation_document_ref_license_ref) { violation('DocumentRef-foo:LicenseRef-bar', 'dependency_3') }

  let(:document_ref_license_ref_uppercase) { report('DocumentRef-FOO:LicenseRef-Bar', 'dependency_4') }
  let(:violation_document_ref_license_ref_uppercase) do
    violation('DocumentRef-FOO:LicenseRef-Bar', 'dependency_4')
  end

  let(:document_ref_and_mit) { report('DocumentRef-foo:LicenseRef-bar AND MIT', 'dependency_5') }
  let(:violation_document_ref_and_mit) { violation('DocumentRef-foo:LicenseRef-bar AND MIT', 'dependency_5') }

  let(:document_ref_or_mit) { report('DocumentRef-foo:LicenseRef-bar OR MIT', 'dependency_6') }
  let(:violation_document_ref_or_mit) { violation('DocumentRef-foo:LicenseRef-bar OR MIT', 'dependency_6') }

  let(:license_ref_and_mit) { report('LicenseRef-Proprietary AND MIT', 'dependency_5') }
  let(:violation_license_ref_and_mit) { violation('LicenseRef-Proprietary AND MIT', 'dependency_5') }

  let(:mit_only_report) { report('MIT', 'dependency_7') }

  let(:license_ref_or_mit) { report('LicenseRef-Proprietary OR MIT', 'dependency_8') }
  let(:violation_license_ref_or_mit) { violation('LicenseRef-Proprietary OR MIT', 'dependency_8') }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_denied_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # LicenseRef wildcard and case-insensitive matching
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | ['LicenseRef-*'] | ref(:violation_license_ref_proprietary)
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | ['licenseref-*'] | ref(:violation_license_ref_proprietary)
    ref(:empty_report) | ref(:license_ref_proprietary_lowercase) | ['newly_detected'] | ['LicenseRef-*'] | ref(:violation_license_ref_proprietary_lowercase)
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | ['licenseref-proprietary'] | ref(:violation_license_ref_proprietary)
    ref(:empty_report) | ref(:license_ref_proprietary_lowercase) | ['newly_detected'] | ['LicenseRef-Proprietary'] | ref(:violation_license_ref_proprietary_lowercase)

    # -------------------------------------------------------------------------
    # DocumentRef matching is case-insensitive
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:document_ref_license_ref_uppercase) | ['newly_detected'] | ['documentref-foo:licenseref-bar'] | ref(:violation_document_ref_license_ref_uppercase)
    ref(:empty_report) | ref(:document_ref_license_ref) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar'] | ref(:violation_document_ref_license_ref)
    ref(:empty_report) | ref(:document_ref_license_ref) | ['newly_detected'] | ['documentref-foo:licenseref-bar'] | ref(:violation_document_ref_license_ref)

    # -------------------------------------------------------------------------
    # LicenseRef wildcard does not match DocumentRef identifiers
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:document_ref_license_ref) | ['newly_detected'] | ['LicenseRef-*'] | nil

    # -------------------------------------------------------------------------
    # LicenseRef wildcard does not match SPDX identifiers
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_only_report) | ['newly_detected'] | ['LicenseRef-*'] | nil

    # -------------------------------------------------------------------------
    # LicenseRef matching inside compound expressions
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:document_ref_and_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar'] | ref(:violation_document_ref_and_mit)
    ref(:empty_report) | ref(:document_ref_or_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar'] | nil
    ref(:empty_report) | ref(:document_ref_or_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar', 'MIT License'] | ref(:violation_document_ref_or_mit)
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-*'] | ref(:violation_license_ref_and_mit)
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-Proprietary'] | ref(:violation_license_ref_and_mit)
    ref(:empty_report) | ref(:license_ref_or_mit) | ['newly_detected'] | ['LicenseRef-*'] | nil
    ref(:empty_report) | ref(:license_ref_or_mit) | ['newly_detected'] | ['LicenseRef-*', 'MIT License'] | ref(:violation_license_ref_or_mit)

    # -------------------------------------------------------------------------
    # Standard SPDX identifiers remain case-sensitive
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['mit license'] | nil
  end
  # rubocop:enable Layout/LineLength
end
