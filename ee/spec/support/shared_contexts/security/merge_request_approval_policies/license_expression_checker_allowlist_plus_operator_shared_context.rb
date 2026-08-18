# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
RSpec.shared_context 'for license_expression_checker allowlist PLUS operator' do
  include_context 'for license_expression_checker'

  # PLUS semantics (allowlist): an allowlist entry covers a report entry using the same
  # version-range logic as the denylist, inverted. A report entry is allowed when the
  # allowlist contains an entry that covers it.

  let(:cddl_1_plus) { report('CDDL-1.0+', 'dependency_1') }
  let(:violation_cddl_1_plus) { violation('CDDL-1.0+', 'dependency_1') }

  let(:mit_plus) { report('MIT+', 'dependency_0') }
  let(:violation_mit_plus) { violation('MIT+', 'dependency_0') }

  let(:cddl_2_plus) { report('CDDL-2.0+', 'dependency_2') }
  let(:violation_cddl_2_plus) { violation('CDDL-2.0+', 'dependency_2') }

  let(:license_ref_plus) { report('LicenseRef-Proprietary+', 'dependency_3') }
  let(:violation_license_ref_plus) { violation('LicenseRef-Proprietary+', 'dependency_3') }

  let(:plus_and_mit) { report('CDDL-1.0+ AND MIT', 'dependency_4') }
  let(:violation_plus_and_mit) { violation('CDDL-1.0+ AND MIT', 'dependency_4') }

  let(:plus_with_bison) { report('CDDL-1.0+ WITH Bison-exception-2.2', 'dependency_5') }
  let(:violation_plus_with_bison) { violation('CDDL-1.0+ WITH Bison-exception-2.2', 'dependency_5') }

  let(:parenthesized_plus) { report('(CDDL-1.0+)', 'dependency_6') }
  let(:violation_parenthesized_plus) { violation('(CDDL-1.0+)', 'dependency_6') }

  let(:parenthesized_plus_and_mit) { report('(CDDL-1.0+) AND MIT', 'dependency_7') }
  let(:violation_parenthesized_plus_and_mit) { violation('(CDDL-1.0+) AND MIT', 'dependency_7') }

  let(:parenthesized_plus_or_mit) { report('(CDDL-1.0+) OR MIT', 'dependency_8') }
  let(:violation_parenthesized_plus_or_mit) { violation('(CDDL-1.0+) OR MIT', 'dependency_8') }

  let(:cddl_1_10_plus) { report('CDDL-1.10+', 'dependency_9') }
  let(:violation_cddl_1_10_plus) { violation('CDDL-1.10+', 'dependency_9') }

  let(:cddl_1_1_1_plus) { report('CDDL-1.1.1+', 'dependency_10') }
  let(:violation_cddl_1_1_1_plus) { violation('CDDL-1.1.1+', 'dependency_10') }

  let(:cddl_1_1_plus) { report('CDDL-1.1+', 'dependency_11') }
  let(:violation_cddl_1_1_plus) { violation('CDDL-1.1+', 'dependency_11') }

  let(:gpl_2_only_plus) { report('GPL-2.0-only+', 'dependency_12') }
  let(:violation_gpl_2_only_plus) { violation('GPL-2.0-only+', 'dependency_12') }

  let(:gpl_2_plus) { report('GPL-2.0+', 'dependency_13') }
  let(:violation_gpl_2_plus) { violation('GPL-2.0+', 'dependency_13') }
  let(:lgpl_2_plus) { report('LGPL-2.0+', 'dependency_14') }
  let(:violation_lgpl_2_plus) { violation('LGPL-2.0+', 'dependency_14') }

  let(:cddl_1_10) { report('CDDL-1.10', 'dependency_15') }
  let(:violation_cddl_1_10) { violation('CDDL-1.10', 'dependency_15') }

  let(:mit_1) { report('MIT-1', 'dependency_16') }
  let(:violation_mit_1) { violation('MIT-1', 'dependency_16') }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_allowed_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Report base vs exact allowlist entry
    # -------------------------------------------------------------------------

    # Allowlist has exact base -> no violation
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['CDDL-1.0']  | nil
    # Allowlist has plus entry covering the base -> no violation
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['CDDL-1.0+'] | nil
    # Allowlist has unrelated license -> violation
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['MIT'] | ref(:violation_cddl_1_plus)

    # detected: violation when the expression exists in the target branch and is not allowed
    ref(:cddl_1_plus) | ref(:empty_report) | ['detected']       | ['MIT']      | ref(:violation_cddl_1_plus)
    ref(:cddl_1_plus) | ref(:empty_report) | ['detected']       | ['CDDL-1.0'] | nil
    ref(:empty_report) | ref(:cddl_1_plus) | ['detected']       | ['MIT']      | nil

    # newly_detected: no violation when the expression already exists in the target branch
    ref(:cddl_1_plus) | ref(:cddl_1_plus) | ['newly_detected'] | ['MIT'] | nil

    # both states combined
    ref(:cddl_1_plus) | ref(:cddl_1_plus) | %w[newly_detected detected] | ['MIT'] | ref(:violation_cddl_1_plus)

    ref(:empty_report) | ref(:mit_plus) | ['newly_detected'] | ['MIT']  | nil
    ref(:empty_report) | ref(:mit_plus) | ['newly_detected'] | ['MIT+'] | nil
    ref(:empty_report) | ref(:mit_plus) | ['newly_detected'] | ['Apache License 2.0'] | ref(:violation_mit_plus)

    # -------------------------------------------------------------------------
    # Allowlist PLUS covers report base by version range
    # -------------------------------------------------------------------------

    # Allowlist CDDL-1.0+ covers CDDL-2.0+ report (2.0 >= 1.0) -> no violation
    ref(:empty_report) | ref(:cddl_2_plus) | ['newly_detected'] | ['CDDL-1.0+'] | nil
    # Allowlist CDDL-2.0+ does NOT cover CDDL-1.0+ report (1.0 < 2.0) -> violation
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['CDDL-2.0+'] | ref(:violation_cddl_1_plus)

    # -------------------------------------------------------------------------
    # LicenseRef entries are treated as literals (no version expansion)
    # -------------------------------------------------------------------------

    # `LicenseRef-Proprietary+` takes the LicenseRef branch in allowed_plus_node? and is
    # matched via matches_policy_name?. The wildcard `LicenseRef-*` still matches because
    # license_ref_identifier? does a prefix check on the downcased value, and
    # "licenseref-proprietary+" starts with "licenseref-" despite the trailing `+`.
    # The exact `LicenseRef-Proprietary+` entry also matches for the same reason.
    # The plain `LicenseRef-Proprietary` (without `+`) does NOT match because the node
    # value is "LicenseRef-Proprietary+" and the exact string comparison fails.
    ref(:empty_report) | ref(:license_ref_plus) | ['newly_detected'] | ['LicenseRef-Proprietary+'] | nil
    ref(:empty_report) | ref(:license_ref_plus) | ['newly_detected'] | ['LicenseRef-*'] | nil
    ref(:empty_report) | ref(:license_ref_plus) | ['newly_detected'] | ['LicenseRef-Proprietary'] | ref(:violation_license_ref_plus)
    ref(:empty_report) | ref(:license_ref_plus) | ['newly_detected'] | ['MIT'] | ref(:violation_license_ref_plus)

    # -------------------------------------------------------------------------
    # PLUS node in compound expressions
    # -------------------------------------------------------------------------

    # AND: both children must be allowed
    ref(:empty_report) | ref(:plus_and_mit) | ['newly_detected'] | ['CDDL-1.0', 'MIT License'] | nil
    ref(:empty_report) | ref(:plus_and_mit) | ['newly_detected'] | ['CDDL-1.0']                | ref(:violation_plus_and_mit)
    ref(:empty_report) | ref(:plus_and_mit) | ['newly_detected'] | ['MIT License']             | ref(:violation_plus_and_mit)

    # WITH: base license allowed -> no violation
    ref(:empty_report) | ref(:plus_with_bison) | ['newly_detected'] | ['CDDL-1.0'] | nil
    ref(:empty_report) | ref(:plus_with_bison) | ['newly_detected'] | ['MIT'] | ref(:violation_plus_with_bison)

    # -------------------------------------------------------------------------
    # Parenthesized PLUS expression
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:parenthesized_plus) | ['newly_detected'] | ['CDDL-1.0'] | nil
    ref(:empty_report) | ref(:parenthesized_plus) | ['newly_detected'] | ['MIT'] | ref(:violation_parenthesized_plus)

    # AND: both children must be allowed
    ref(:empty_report) | ref(:parenthesized_plus_and_mit) | ['newly_detected'] | ['CDDL-1.0', 'MIT License'] | nil
    ref(:empty_report) | ref(:parenthesized_plus_and_mit) | ['newly_detected'] | ['CDDL-1.0']                | ref(:violation_parenthesized_plus_and_mit)

    # OR: any child allowed is sufficient
    ref(:empty_report) | ref(:parenthesized_plus_or_mit) | ['newly_detected'] | ['CDDL-1.0']                | nil
    ref(:empty_report) | ref(:parenthesized_plus_or_mit) | ['newly_detected'] | ['MIT License']             | nil
    ref(:empty_report) | ref(:parenthesized_plus_or_mit) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_parenthesized_plus_or_mit)

    # -------------------------------------------------------------------------
    # Allowlist PLUS covers plain (non-plus) report id
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:cddl_1_10) | ['newly_detected'] | ['CDDL-1.0+']  | nil
    ref(:empty_report) | ref(:cddl_1_10) | ['newly_detected'] | ['CDDL-1.20+'] | ref(:violation_cddl_1_10)

    # -------------------------------------------------------------------------
    # Multi-digit version comparisons
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:cddl_1_10_plus) | ['newly_detected'] | ['CDDL-1.2+']   | nil
    ref(:empty_report) | ref(:cddl_1_10_plus) | ['newly_detected'] | ['CDDL-1.20+']  | ref(:violation_cddl_1_10_plus)
    ref(:empty_report) | ref(:cddl_1_1_1_plus) | ['newly_detected'] | ['CDDL-1.1+']  | nil
    ref(:empty_report) | ref(:cddl_1_1_1_plus) | ['newly_detected'] | ['CDDL-1.1.2+'] | ref(:violation_cddl_1_1_1_plus)
    ref(:empty_report) | ref(:cddl_1_1_plus) | ['newly_detected'] | ['CDDL-1.1.0+'] | nil

    ref(:empty_report) | ref(:gpl_2_only_plus) | ['newly_detected'] | ['GPL-2.0-only']  | nil
    ref(:empty_report) | ref(:gpl_2_only_plus) | ['newly_detected'] | ['GPL-2.0-only+'] | nil

    # Different license families are not interchangeable
    ref(:empty_report) | ref(:lgpl_2_plus) | ['newly_detected'] | ['GPL-2.0+']  | ref(:violation_lgpl_2_plus)
    ref(:empty_report) | ref(:gpl_2_plus)  | ['newly_detected'] | ['LGPL-2.0+'] | ref(:violation_gpl_2_plus)
    ref(:empty_report) | ref(:lgpl_2_plus) | ['newly_detected'] | ['LGPL-2.0+'] | nil

    # -------------------------------------------------------------------------
    # Single-digit suffix licenses (e.g. MIT-0) are not treated as versioned series
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_1) | ['newly_detected'] | ['MIT-0+'] | ref(:violation_mit_1)
  end
  # rubocop:enable Layout/LineLength
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
