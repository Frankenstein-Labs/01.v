# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker LicenseRef operator with package exceptions' do
  include_context 'for license_expression_checker with package exceptions'

  let(:license_ref_proprietary)           { report('LicenseRef-Proprietary', dependency: 'foo') }
  let(:violation_license_ref_proprietary) { violation('LicenseRef-Proprietary', 'foo') }

  let(:foo_excluded)               { ['pkg:gem/foo'] }
  let(:except_license_ref)         { { 'LicenseRef-Proprietary' => foo_excluded } }
  let(:except_license_ref_wildcard) { { 'LicenseRef-*' => foo_excluded } }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_state, :policy_names, :excluded_packages, :violated_licenses) do
    # Exact LicenseRef denied; excepting the dependency under the same name clears it.
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | :denied | ['LicenseRef-Proprietary'] | ref(:except_license_ref) | nil

    # No exception -> violation.
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | :denied | ['LicenseRef-Proprietary'] | ref(:no_exceptions) | ref(:violation_license_ref_proprietary)

    # Wildcard denied; an exception keyed by the wildcard policy name clears it.
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | :denied | ['LicenseRef-*'] | ref(:except_license_ref_wildcard) | nil

    # Allowlist: exact LicenseRef allowed; carving the dependency out makes it a violation.
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | :allowed | ['LicenseRef-Proprietary'] | ref(:except_license_ref) | ref(:violation_license_ref_proprietary)

    # Allowlist: exact LicenseRef allowed, no carve-out -> compliant.
    ref(:empty_report) | ref(:license_ref_proprietary) | ['newly_detected'] | :allowed | ['LicenseRef-Proprietary'] | ref(:no_exceptions) | nil
  end
  # rubocop:enable Layout/LineLength
end
