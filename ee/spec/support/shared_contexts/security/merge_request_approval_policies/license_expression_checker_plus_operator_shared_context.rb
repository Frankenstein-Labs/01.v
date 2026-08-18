# frozen_string_literal: true

# rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
RSpec.shared_context 'for license_expression_checker PLUS operator' do
  include_context 'for license_expression_checker'

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

  let(:plus_with_mit) { report('CDDL-1.0+ WITH Bison-exception-2.2', 'dependency_5') }
  let(:violation_plus_with_mit) { violation('CDDL-1.0+ WITH Bison-exception-2.2', 'dependency_5') }

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
  let(:lgpl_2_plus) { report('LGPL-2.0+', 'dependency_14') }
  let(:violation_lgpl_2_plus) { violation('LGPL-2.0+', 'dependency_14') }

  let(:cddl_1_10) { report('CDDL-1.10', 'dependency_15') }
  let(:violation_cddl_1_10) { violation('CDDL-1.10', 'dependency_15') }

  let(:mit_1) { report('MIT-1', 'dependency_16') }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_denied_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Report base vs exact policy
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['CDDL-1.0']  | ref(:violation_cddl_1_plus)
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['CDDL-1.0+'] | ref(:violation_cddl_1_plus)
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['MIT'] | nil

    ref(:empty_report) | ref(:mit_plus) | ['newly_detected'] | ['MIT'] | ref(:violation_mit_plus)
    ref(:empty_report) | ref(:mit_plus) | ['newly_detected'] | ['MIT+'] | ref(:violation_mit_plus)
    ref(:empty_report) | ref(:mit_plus) | ['newly_detected'] | ['Apache License 2.0'] | nil

    # -------------------------------------------------------------------------
    # Policy PLUS covers report base
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:cddl_2_plus) | ['newly_detected'] | ['CDDL-1.0+'] | ref(:violation_cddl_2_plus)
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | ['CDDL-2.0+'] | nil

    # -------------------------------------------------------------------------
    # LicenseRef entries are treated as literals
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:license_ref_plus) | ['newly_detected'] | ['LicenseRef-Proprietary'] | nil
    ref(:empty_report) | ref(:license_ref_plus) | ['newly_detected'] | ['LicenseRef-Proprietary+'] | ref(:violation_license_ref_plus)

    # -------------------------------------------------------------------------
    # PLUS node in compound expressions
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:plus_and_mit) | ['newly_detected'] | ['CDDL-1.0'] | ref(:violation_plus_and_mit)
    ref(:empty_report) | ref(:plus_with_mit) | ['newly_detected'] | ['CDDL-1.0'] | ref(:violation_plus_with_mit)

    # -------------------------------------------------------------------------
    # Parenthesized PLUS expression
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:parenthesized_plus) | ['newly_detected'] | ['CDDL-1.0'] | ref(:violation_parenthesized_plus)
    ref(:empty_report) | ref(:parenthesized_plus_and_mit) | ['newly_detected'] | ['CDDL-1.0'] | ref(:violation_parenthesized_plus_and_mit)
    ref(:empty_report) | ref(:parenthesized_plus_or_mit) | ['newly_detected'] | ['CDDL-1.0', 'MIT License'] | ref(:violation_parenthesized_plus_or_mit)

    # -------------------------------------------------------------------------
    # Policy PLUS covers plain (non-plus) report id
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:cddl_1_10) | ['newly_detected'] | ['CDDL-1.0+'] | ref(:violation_cddl_1_10)
    ref(:empty_report) | ref(:cddl_1_10) | ['newly_detected'] | ['CDDL-1.20+'] | nil

    # -------------------------------------------------------------------------
    # Multi-digit version comparisons
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:cddl_1_10_plus) | ['newly_detected'] | ['CDDL-1.2+'] | ref(:violation_cddl_1_10_plus)
    ref(:empty_report) | ref(:cddl_1_10_plus) | ['newly_detected'] | ['CDDL-1.20+'] | nil
    ref(:empty_report) | ref(:cddl_1_1_1_plus) | ['newly_detected'] | ['CDDL-1.1+'] | ref(:violation_cddl_1_1_1_plus)
    ref(:empty_report) | ref(:cddl_1_1_1_plus) | ['newly_detected'] | ['CDDL-1.1.2+'] | nil
    ref(:empty_report) | ref(:cddl_1_1_plus) | ['newly_detected'] | ['CDDL-1.1.0+'] | ref(:violation_cddl_1_1_plus)

    ref(:empty_report) | ref(:gpl_2_only_plus) | ['newly_detected'] | ['GPL-2.0-only'] | ref(:violation_gpl_2_only_plus)
    ref(:empty_report) | ref(:gpl_2_only_plus) | ['newly_detected'] | ['GPL-2.0-only+'] | ref(:violation_gpl_2_only_plus)

    ref(:empty_report) | ref(:lgpl_2_plus) | ['newly_detected'] | ['GPL-2.0+'] | nil
    ref(:empty_report) | ref(:gpl_2_plus) | ['newly_detected'] | ['LGPL-2.0+'] | nil
    ref(:empty_report) | ref(:lgpl_2_plus) | ['newly_detected'] | ['LGPL-2.0+'] | ref(:violation_lgpl_2_plus)

    # -------------------------------------------------------------------------
    # Single-digit suffix licenses (e.g. MIT-0) are not treated as versioned series
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_1) | ['newly_detected'] | ['MIT-0+'] | nil
  end
  # rubocop:enable Layout/LineLength
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
