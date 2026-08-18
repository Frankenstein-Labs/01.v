# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker allowlist LicenseRef operator' do
  include_context 'for license_expression_checker'

  # LicenseRef semantics (allowlist): wildcard `LicenseRef-*` in the allowlist permits any
  # `LicenseRef-` identifier. DocumentRef identifiers are NOT matched by the wildcard.

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

  let(:license_ref_and_mit) { report('LicenseRef-Proprietary AND MIT', 'dependency_5') }
  let(:violation_license_ref_and_mit) { violation('LicenseRef-Proprietary AND MIT', 'dependency_5') }

  let(:document_ref_and_mit) { report('DocumentRef-foo:LicenseRef-bar AND MIT', 'dependency_6') }
  let(:violation_document_ref_and_mit) { violation('DocumentRef-foo:LicenseRef-bar AND MIT', 'dependency_6') }

  let(:license_ref_or_mit) { report('LicenseRef-Proprietary OR MIT', 'dependency_7') }
  let(:violation_license_ref_or_mit) { violation('LicenseRef-Proprietary OR MIT', 'dependency_7') }

  let(:document_ref_or_mit) { report('DocumentRef-foo:LicenseRef-bar OR MIT', 'dependency_8') }
  let(:violation_document_ref_or_mit) { violation('DocumentRef-foo:LicenseRef-bar OR MIT', 'dependency_8') }

  let(:mit_only_report) { report('MIT', 'dependency_9') }
  let(:violation_mit_only) { violation('MIT', 'dependency_9') }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_allowed_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # LicenseRef wildcard and case-insensitive matching -> no violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:license_ref_proprietary)          | ['newly_detected'] | ['LicenseRef-*']            | nil
    ref(:empty_report) | ref(:license_ref_proprietary)          | ['newly_detected'] | ['licenseref-*']            | nil
    ref(:empty_report) | ref(:license_ref_proprietary_lowercase) | ['newly_detected'] | ['LicenseRef-*']           | nil
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | ['licenseref-proprietary'] | nil
    ref(:empty_report) | ref(:license_ref_proprietary_lowercase) | ['newly_detected'] | ['LicenseRef-Proprietary'] | nil

    # -------------------------------------------------------------------------
    # LicenseRef not in allowlist -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | ['MIT License'] | ref(:violation_license_ref_proprietary)

    # -------------------------------------------------------------------------
    # DocumentRef matching is case-insensitive -> no violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:document_ref_license_ref_uppercase) | ['newly_detected'] | ['documentref-foo:licenseref-bar'] | nil
    ref(:empty_report) | ref(:document_ref_license_ref)           | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar'] | nil
    ref(:empty_report) | ref(:document_ref_license_ref)           | ['newly_detected'] | ['documentref-foo:licenseref-bar'] | nil

    # -------------------------------------------------------------------------
    # LicenseRef wildcard does NOT match DocumentRef identifiers -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:document_ref_license_ref) | ['newly_detected'] | ['LicenseRef-*'] | ref(:violation_document_ref_license_ref)

    # -------------------------------------------------------------------------
    # LicenseRef wildcard does NOT match standard SPDX identifiers -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_only_report) | ['newly_detected'] | ['LicenseRef-*'] | ref(:violation_mit_only)

    # -------------------------------------------------------------------------
    # LicenseRef matching inside AND compound expressions
    # -------------------------------------------------------------------------

    # Both children allowed -> no violation
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-*', 'MIT License'] | nil
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-Proprietary', 'MIT License'] | nil

    # LicenseRef allowed but MIT not -> violation (AND requires all children allowed)
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-*']            | ref(:violation_license_ref_and_mit)
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-Proprietary']  | ref(:violation_license_ref_and_mit)

    # MIT allowed but LicenseRef not -> violation
    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['MIT License'] | ref(:violation_license_ref_and_mit)

    ref(:empty_report) | ref(:document_ref_and_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar', 'MIT License'] | nil
    ref(:empty_report) | ref(:document_ref_and_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar']                | ref(:violation_document_ref_and_mit)

    # -------------------------------------------------------------------------
    # LicenseRef matching inside OR compound expressions
    # -------------------------------------------------------------------------

    # LicenseRef allowed -> no violation (OR: any child allowed is sufficient)
    ref(:empty_report) | ref(:license_ref_or_mit) | ['newly_detected'] | ['LicenseRef-*']           | nil
    ref(:empty_report) | ref(:license_ref_or_mit) | ['newly_detected'] | ['LicenseRef-Proprietary'] | nil

    # MIT allowed -> no violation
    ref(:empty_report) | ref(:license_ref_or_mit) | ['newly_detected'] | ['MIT License'] | nil

    # Neither allowed -> violation
    ref(:empty_report) | ref(:license_ref_or_mit) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License'] | ref(:violation_license_ref_or_mit)

    ref(:empty_report) | ref(:document_ref_or_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar'] | nil
    ref(:empty_report) | ref(:document_ref_or_mit) | ['newly_detected'] | ['MIT License']                                    | nil
    ref(:empty_report) | ref(:document_ref_or_mit) | ['newly_detected'] | ['DocumentRef-foo:LicenseRef-bar', 'MIT License']  | nil
    ref(:empty_report) | ref(:document_ref_or_mit) | ['newly_detected'] | ['LicenseRef-*']                                   | ref(:violation_document_ref_or_mit)

    # -------------------------------------------------------------------------
    # Standard SPDX identifiers remain case-sensitive
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:license_ref_and_mit) | ['newly_detected'] | ['LicenseRef-*', 'mit license'] | ref(:violation_license_ref_and_mit)
  end
  # rubocop:enable Layout/LineLength
end
