# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker allowlist AND operator' do
  include_context 'for license_expression_checker'

  # AND semantics (allowlist): ALL children must be allowed.
  # If any child is not in the allowlist, the expression is a violation.

  # ---------------------------------------------------------------------------
  # Two-term AND expressions
  # ---------------------------------------------------------------------------

  let(:mit_and_apache)           { report('MIT AND Apache-2.0', 'dependency_1') }
  let(:violation_mit_and_apache) { violation('MIT AND Apache-2.0', 'dependency_1') }

  let(:apache_and_mit)           { report('Apache-2.0 AND MIT', 'dependency_2') }
  let(:violation_apache_and_mit) { violation('Apache-2.0 AND MIT', 'dependency_2') }

  let(:mit_and_apache_and_apache_and_mit) do
    [
      *report('MIT AND Apache-2.0', 'dependency_1'),
      *report('Apache-2.0 AND MIT', 'dependency_2')
    ]
  end

  let(:violation_mit_and_apache_and_apache_and_mit) do
    violation('MIT AND Apache-2.0', 'dependency_1').merge(
      violation('Apache-2.0 AND MIT', 'dependency_2'))
  end

  let(:mit_and_gpl)           { report('MIT AND GPL-3.0-only', 'dependency_3') }
  let(:violation_mit_and_gpl) { violation('MIT AND GPL-3.0-only', 'dependency_3') }

  # ---------------------------------------------------------------------------
  # Three-term AND expression (left-associative tree: (MIT AND Apache-2.0) AND GPL-3.0-only)
  # ---------------------------------------------------------------------------

  let(:mit_and_apache_and_gpl)           { report('MIT AND Apache-2.0 AND GPL-3.0-only', 'dependency_4') }
  let(:violation_mit_and_apache_and_gpl) { violation('MIT AND Apache-2.0 AND GPL-3.0-only', 'dependency_4') }

  # ---------------------------------------------------------------------------
  # Lowercase "and" operator
  # ---------------------------------------------------------------------------

  let(:mit_and_apache_lowercase)           { report('MIT and Apache-2.0', 'dependency_5') }
  let(:violation_mit_and_apache_lowercase) { violation('MIT and Apache-2.0', 'dependency_5') }

  # ---------------------------------------------------------------------------
  # Parenthesised AND expression
  # ---------------------------------------------------------------------------

  let(:mit_and_apache_parenthesised)           { report('(MIT AND Apache-2.0)', 'dependency_6') }
  let(:violation_mit_and_apache_parenthesised) { violation('(MIT AND Apache-2.0)', 'dependency_6') }

  # ---------------------------------------------------------------------------
  # AND expression mixed with a plain-name entry
  # ---------------------------------------------------------------------------

  let(:mit_and_apache_with_plain_gpl) do
    [
      *report('MIT AND Apache-2.0', 'dependency_1'),
      ['GPL-3.0-only', 'GNU General Public License v3.0 only', 'dependency_7']
    ]
  end

  let(:violation_gpl) { violation('GNU General Public License v3.0 only', 'dependency_7') }
  let(:violation_mit_and_apache_with_plain_gpl) do
    violation('MIT AND Apache-2.0', 'dependency_1').merge(
      violation('GNU General Public License v3.0 only', 'dependency_7'))
  end

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_allowed_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Two-term AND: both children allowed -> no violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | nil
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Two-term AND: only one child allowed -> violation (the other is not permitted)
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License']                          | ref(:violation_mit_and_apache)
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_mit_and_apache)

    # -------------------------------------------------------------------------
    # Two-term AND: neither child allowed -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_and_apache)

    # -------------------------------------------------------------------------
    # detected: violation when the expression exists in the target branch report and a child is not allowed
    # -------------------------------------------------------------------------

    ref(:mit_and_apache) | ref(:empty_report) | ['detected']       | ['MIT License']                          | ref(:violation_mit_and_apache)
    ref(:empty_report)   | ref(:mit_and_apache) | ['detected']     | ['MIT License']                          | nil

    # -------------------------------------------------------------------------
    # newly_detected: no violation when the expression already exists in the target branch
    # -------------------------------------------------------------------------

    ref(:mit_and_apache) | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License']                        | nil

    # -------------------------------------------------------------------------
    # Both states combined
    # -------------------------------------------------------------------------

    ref(:mit_and_apache) | ref(:mit_and_apache) | %w[newly_detected detected] | ['MIT License'] | ref(:violation_mit_and_apache)

    # -------------------------------------------------------------------------
    # AND is commutative: "Apache-2.0 AND MIT" behaves the same way
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:apache_and_mit) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | nil
    ref(:empty_report) | ref(:apache_and_mit) | ['newly_detected'] | ['MIT License']                          | ref(:violation_apache_and_mit)
    ref(:empty_report) | ref(:apache_and_mit) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_apache_and_mit)

    # -------------------------------------------------------------------------
    # Multiple AND expression entries: each evaluated independently
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_and_apache_and_mit) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | nil
    ref(:empty_report) | ref(:mit_and_apache_and_apache_and_mit) | ['newly_detected'] | ['MIT License']                       | ref(:violation_mit_and_apache_and_apache_and_mit)

    # -------------------------------------------------------------------------
    # Three-term AND: all three allowed -> no violation; any one not allowed -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | nil
    ref(:empty_report) | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']                                          | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report) | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['MIT License', 'GNU General Public License v3.0 only']                        | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report) | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['MIT License'] | ref(:violation_mit_and_apache_and_gpl)

    ref(:mit_and_apache_and_gpl) | ref(:empty_report) | ['detected']       | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | nil
    ref(:mit_and_apache_and_gpl) | ref(:empty_report) | ['detected']       | ['MIT License'] | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report)           | ref(:mit_and_apache_and_gpl) | ['detected'] | ['MIT License'] | nil

    # -------------------------------------------------------------------------
    # Lowercase "and" operator
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_lowercase) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | nil
    ref(:empty_report) | ref(:mit_and_apache_lowercase) | ['newly_detected'] | ['MIT License']                       | ref(:violation_mit_and_apache_lowercase)

    # -------------------------------------------------------------------------
    # Parenthesised AND expression
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_parenthesised) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | nil
    ref(:empty_report) | ref(:mit_and_apache_parenthesised) | ['newly_detected'] | ['MIT License']                       | ref(:violation_mit_and_apache_parenthesised)

    # -------------------------------------------------------------------------
    # AND expression mixed with a plain-name entry: each evaluated independently
    # -------------------------------------------------------------------------

    # Both allowed
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0', 'GNU General Public License v3.0 only'] | nil

    # AND expression not fully allowed, plain entry allowed
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'GNU General Public License v3.0 only'] | ref(:violation_mit_and_apache)

    # AND expression fully allowed, plain entry not allowed
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'Apache License 2.0'] | ref(:violation_gpl)

    # Neither allowed
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License'] | ref(:violation_mit_and_apache_with_plain_gpl)
  end
  # rubocop:enable Layout/LineLength
end
