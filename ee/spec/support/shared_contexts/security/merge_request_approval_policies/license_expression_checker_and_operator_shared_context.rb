# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker AND operator' do
  include_context 'for license_expression_checker'

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
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_denied_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Two-term AND: denying one component is a violation
    # -------------------------------------------------------------------------

    # newly_detected: violation only when the expression is new in the pipeline
    ref(:empty_report)     | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License']                          | ref(:violation_mit_and_apache)
    ref(:empty_report)     | ref(:mit_and_apache) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_mit_and_apache)
    ref(:empty_report)     | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License', 'Apache License 2.0']    | ref(:violation_mit_and_apache)
    ref(:empty_report)     | ref(:mit_and_apache) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # detected: violation when the expression exists in the target branch report
    ref(:mit_and_apache)   | ref(:empty_report)   | ['detected']       | ['MIT License']                          | ref(:violation_mit_and_apache)
    ref(:empty_report)     | ref(:mit_and_apache) | ['detected']       | ['MIT License']                          | nil

    # newly_detected: no violation when the expression already exists in the target branch
    ref(:mit_and_apache)   | ref(:mit_and_apache) | ['newly_detected'] | ['MIT License']                          | nil

    # both states combined
    ref(:mit_and_apache)   | ref(:mit_and_apache) | %w[newly_detected detected] | ['MIT License'] | ref(:violation_mit_and_apache)

    # -------------------------------------------------------------------------
    # AND is commutative: "Apache-2.0 AND MIT" is caught by a policy denying "MIT License"
    # -------------------------------------------------------------------------

    ref(:empty_report)     | ref(:apache_and_mit) | ['newly_detected'] | ['MIT License']                          | ref(:violation_apache_and_mit)
    ref(:empty_report)     | ref(:apache_and_mit) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_apache_and_mit)
    ref(:empty_report)     | ref(:apache_and_mit) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Multiple AND expression entries, policy denies one shared component
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_and_apache_and_mit) | ['newly_detected'] | ['MIT License']        | ref(:violation_mit_and_apache_and_apache_and_mit)
    ref(:empty_report) | ref(:mit_and_apache_and_apache_and_mit) | ['newly_detected'] | ['Apache License 2.0'] | ref(:violation_mit_and_apache_and_apache_and_mit)

    # -------------------------------------------------------------------------
    # Three-term AND: denying any one of the three components is a violation
    # (the checker recursively walks the left-associative binary tree)
    # -------------------------------------------------------------------------

    ref(:empty_report)           | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['MIT License']                          | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report)           | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report)           | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report)           | ref(:mit_and_apache_and_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License']    | nil

    ref(:mit_and_apache_and_gpl) | ref(:empty_report)           | ['detected']       | ['MIT License']                          | ref(:violation_mit_and_apache_and_gpl)
    ref(:empty_report)           | ref(:mit_and_apache_and_gpl) | ['detected']       | ['MIT License']                          | nil

    # -------------------------------------------------------------------------
    # Lowercase "and" operator is accepted; component-level matching works identically
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_lowercase) | ['newly_detected'] | ['MIT License']                          | ref(:violation_mit_and_apache_lowercase)
    ref(:empty_report) | ref(:mit_and_apache_lowercase) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_mit_and_apache_lowercase)
    ref(:empty_report) | ref(:mit_and_apache_lowercase) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # Parenthesised AND expression: outer parentheses are handled by the parser
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:mit_and_apache_parenthesised) | ['newly_detected'] | ['MIT License']                          | ref(:violation_mit_and_apache_parenthesised)
    ref(:empty_report) | ref(:mit_and_apache_parenthesised) | ['newly_detected'] | ['Apache License 2.0']                   | ref(:violation_mit_and_apache_parenthesised)
    ref(:empty_report) | ref(:mit_and_apache_parenthesised) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | nil

    # -------------------------------------------------------------------------
    # AND expression mixed with a plain-name entry
    # -------------------------------------------------------------------------

    # Both violated
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License', 'GNU General Public License v3.0 only'] | ref(:violation_mit_and_apache_with_plain_gpl)

    # Only the AND expression violated
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['MIT License']                          | ref(:violation_mit_and_apache)

    # Only the plain-name entry violated
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['GNU General Public License v3.0 only'] | ref(:violation_gpl)

    # Neither violated
    ref(:empty_report) | ref(:mit_and_apache_with_plain_gpl) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License']    | nil
  end
  # rubocop:enable Layout/LineLength
end
