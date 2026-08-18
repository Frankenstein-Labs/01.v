# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker allowlist OR operator' do
  include_context 'for license_expression_checker'

  # OR semantics (allowlist): ANY child allowed is sufficient.
  # A violation only occurs when NO child is in the allowlist.

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
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_allowed_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Two-term OR: one child allowed -> no violation (safe fallback exists)
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | ['Apache License 2.0']                   | nil

    # -------------------------------------------------------------------------
    # Two-term OR: both children allowed -> no violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | nil

    # -------------------------------------------------------------------------
    # Two-term OR: neither child allowed -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache)

    # -------------------------------------------------------------------------
    # detected: violation when the expression exists in the target branch and no child is allowed
    # -------------------------------------------------------------------------

    ref(:mit_or_apache) | ref(:empty_report) | ['detected']       | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache)
    ref(:empty_report)  | ref(:mit_or_apache) | ['detected']      | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # newly_detected: no violation when the expression already exists in the target branch
    # -------------------------------------------------------------------------

    ref(:mit_or_apache) | ref(:mit_or_apache) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Both states combined
    # -------------------------------------------------------------------------

    ref(:mit_or_apache) | ref(:mit_or_apache) | %w[newly_detected detected] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache)

    # -------------------------------------------------------------------------
    # OR is commutative: "Apache-2.0 OR MIT" behaves the same way
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:apache_or_mit) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:apache_or_mit) | ['newly_detected'] | ['Apache License 2.0']                   | nil
    ref(:empty_report) | ref(:apache_or_mit) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_apache_or_mit)

    # -------------------------------------------------------------------------
    # Multiple OR expression entries: each evaluated independently
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_and_apache_or_mit) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:mit_or_apache_and_apache_or_mit) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache_and_apache_or_mit)

    # -------------------------------------------------------------------------
    # Three-term OR: one allowed -> no violation; none allowed -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['MIT License']                                                                   | nil
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['Apache License 2.0']                                                            | nil
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['GNU General Public License v3.0 only']                                          | nil
    ref(:empty_report) | ref(:mit_or_apache_or_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License']                                             | ref(:violation_mit_or_apache_or_gpl)

    ref(:mit_or_apache_or_gpl) | ref(:empty_report) | ['detected']       | ['BSD 2-Clause "Simplified" License']                                             | ref(:violation_mit_or_apache_or_gpl)
    ref(:empty_report)         | ref(:mit_or_apache_or_gpl) | ['detected'] | ['BSD 2-Clause "Simplified" License'] | nil

    # -------------------------------------------------------------------------
    # Lowercase "or" operator
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_lowercase) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:mit_or_apache_lowercase) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache_lowercase)

    # -------------------------------------------------------------------------
    # Parenthesised OR expression
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_or_apache_parenthesised) | ['newly_detected'] | ['MIT License']                          | nil
    ref(:empty_report) | ref(:mit_or_apache_parenthesised) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache_parenthesised)

    # -------------------------------------------------------------------------
    # OR expression mixed with a plain-name entry: each evaluated independently
    # -------------------------------------------------------------------------

    # Both allowed (OR has a safe child; plain entry is allowed)
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'GNU General Public License v3.0 only'] | nil

    # OR expression has no allowed child; plain entry is allowed
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_or_apache)

    # OR expression has a safe child; plain entry is not allowed
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License'] | ref(:violation_gpl)

    # Neither allowed
    ref(:empty_report) | ref(:mit_or_apache_with_plain_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License'] | ref(:violation_mit_or_apache_with_plain_gpl)
  end
  # rubocop:enable Layout/LineLength
end
