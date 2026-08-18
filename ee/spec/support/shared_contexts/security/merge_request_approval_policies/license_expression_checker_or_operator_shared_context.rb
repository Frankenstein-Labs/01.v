# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker OR operator' do
  include_context 'for license_expression_checker'

  # OR semantics (optimistic): a violation only occurs when ALL components of the
  # OR expression are denied. If at least one component is allowed, the dependency
  # can be used under that license and there is no violation.

  # ---------------------------------------------------------------------------
  # Two-term OR expressions
  # ---------------------------------------------------------------------------

  let(:mit_or_apache)           { report('MIT OR Apache-2.0', 'dependency_1') }
  let(:violation_mit_or_apache) { violation('MIT OR Apache-2.0', 'dependency_1') }

  let(:apache_or_mit)           { report('Apache-2.0 OR MIT', 'dependency_2') }
  let(:violation_apache_or_mit) { violation('Apache-2.0 OR MIT', 'dependency_2') }

  let(:mit_or_apache_and_apache_or_mit) do
    [
      *report('MIT OR Apache-2.0', 'dependency_1'),
      *report('Apache-2.0 OR MIT', 'dependency_2')
    ]
  end

  let(:violation_mit_or_apache_and_apache_or_mit) do
    violation('MIT OR Apache-2.0', 'dependency_1').merge(
      violation('Apache-2.0 OR MIT', 'dependency_2'))
  end

  let(:mit_or_gpl)           { report('MIT OR GPL-3.0-only', 'dependency_3') }
  let(:violation_mit_or_gpl) { violation('MIT OR GPL-3.0-only', 'dependency_3') }

  # ---------------------------------------------------------------------------
  # Three-term OR expression (left-associative tree: (MIT OR Apache-2.0) OR GPL-3.0-only)
  # ---------------------------------------------------------------------------

  let(:mit_or_apache_or_gpl)           { report('MIT OR Apache-2.0 OR GPL-3.0-only', 'dependency_4') }
  let(:violation_mit_or_apache_or_gpl) { violation('MIT OR Apache-2.0 OR GPL-3.0-only', 'dependency_4') }

  # ---------------------------------------------------------------------------
  # Lowercase "or" operator
  # ---------------------------------------------------------------------------

  let(:mit_or_apache_lowercase)           { report('MIT or Apache-2.0', 'dependency_5') }
  let(:violation_mit_or_apache_lowercase) { violation('MIT or Apache-2.0', 'dependency_5') }

  # ---------------------------------------------------------------------------
  # Parenthesised OR expression
  # ---------------------------------------------------------------------------

  let(:mit_or_apache_parenthesised)           { report('(MIT OR Apache-2.0)', 'dependency_6') }
  let(:violation_mit_or_apache_parenthesised) { violation('(MIT OR Apache-2.0)', 'dependency_6') }

  # ---------------------------------------------------------------------------
  # OR expression mixed with a plain-name entry
  # ---------------------------------------------------------------------------

  let(:mit_or_apache_with_plain_gpl) do
    [
      *report('MIT OR Apache-2.0', 'dependency_1'),
      ['GPL-3.0-only', 'GNU General Public License v3.0 only', 'dependency_7']
    ]
  end

  let(:violation_gpl) { violation('GNU General Public License v3.0 only', 'dependency_7') }
  let(:violation_mit_or_apache_with_plain_gpl) do
    violation('MIT OR Apache-2.0', 'dependency_1').merge(
      violation('GNU General Public License v3.0 only', 'dependency_7'))
  end

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_denied_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Two-term OR: denying only one component is NOT a violation
    # (the other license is still a safe fallback)
    # -------------------------------------------------------------------------

    # newly_detected: no violation when only one component is denied
    ref(:empty_report)     | ref(:mit_or_apache) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report)     | ref(:mit_or_apache) | ['newly_detected'] | ['Apache License 2.0']                   | nil

    # newly_detected: violation only when ALL components are denied
    ref(:empty_report)     | ref(:mit_or_apache) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | ref(:violation_mit_or_apache)

    # newly_detected: no violation when the denied license is not in the expression
    ref(:empty_report)     | ref(:mit_or_apache) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # detected: violation when the expression exists in the target branch report and all components are denied
    ref(:mit_or_apache) | ref(:empty_report) | ['detected'] | ['MIT License', 'Apache License 2.0'] | ref(:violation_mit_or_apache)
    ref(:empty_report) | ref(:mit_or_apache) | ['detected'] | ['MIT License', 'Apache License 2.0'] | nil

    # newly_detected: no violation when the expression already exists in the target branch
    ref(:mit_or_apache) | ref(:mit_or_apache) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | nil

    # both states combined
    ref(:mit_or_apache) | ref(:mit_or_apache) | %w[newly_detected detected] | ['MIT License', 'Apache License 2.0'] | ref(:violation_mit_or_apache)

    # -------------------------------------------------------------------------
    # OR is commutative: "Apache-2.0 OR MIT" behaves the same way
    # -------------------------------------------------------------------------

    ref(:empty_report)     | ref(:apache_or_mit) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report)     | ref(:apache_or_mit) | ['newly_detected'] | ['Apache License 2.0']                   | nil
    ref(:empty_report)     | ref(:apache_or_mit) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | ref(:violation_apache_or_mit)
    ref(:empty_report)     | ref(:apache_or_mit) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Multiple OR expression entries, policy denies all shared components
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_and_apache_or_mit) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | ref(:violation_mit_or_apache_and_apache_or_mit)
    ref(:empty_report) | ref(:mit_or_apache_and_apache_or_mit) | ['newly_detected'] | ['MIT License'] | nil

    # -------------------------------------------------------------------------
    # Three-term OR: violation only when all three components are denied
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['MIT License']                                                                    | nil
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']                                              | nil
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only']      | ref(:violation_mit_or_apache_or_gpl)
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License']                                              | nil

    ref(:mit_or_apache_or_gpl) | ref(:empty_report) | ['detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache_or_gpl)
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Lowercase "or" operator is accepted; component-level matching works identically
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_lowercase) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:mit_or_apache_lowercase) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | ref(:violation_mit_or_apache_lowercase)
    ref(:empty_report) | ref(:mit_or_apache_lowercase) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Parenthesised OR expression: outer parentheses are handled by the parser
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_parenthesised) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:mit_or_apache_parenthesised) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | ref(:violation_mit_or_apache_parenthesised)
    ref(:empty_report) | ref(:mit_or_apache_parenthesised) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # OR expression mixed with a plain-name entry
    # -------------------------------------------------------------------------

    # Both violated (OR expression: all components denied; plain entry: denied)
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache_with_plain_gpl)

    # Only the OR expression violated (all its components denied; plain entry not denied)
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | ref(:violation_mit_or_apache)

    # Only the plain-name entry violated (OR expression has a safe component)
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_gpl)

    # Neither violated
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License'] | nil
  end
  # rubocop:enable Layout/LineLength
end
