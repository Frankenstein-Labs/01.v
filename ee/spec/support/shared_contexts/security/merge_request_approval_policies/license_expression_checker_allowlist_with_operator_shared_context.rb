# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker allowlist WITH operator' do
  include_context 'for license_expression_checker'

  # WITH semantics (allowlist): base license allowed -> no violation.
  # Full expression string in the allowlist also permits it.
  # Exception identifier alone in the allowlist does NOT permit the expression.

  # ---------------------------------------------------------------------------
  # Basic WITH expressions
  # ---------------------------------------------------------------------------

  let(:gpl_with_bison)           { report('GPL-2.0-or-later WITH Bison-exception-2.2', 'dependency_1') }
  let(:violation_gpl_with_bison) { violation('GPL-2.0-or-later WITH Bison-exception-2.2', 'dependency_1') }

  # ---------------------------------------------------------------------------
  # Lowercase "with" operator
  # ---------------------------------------------------------------------------

  let(:gpl_with_bison_lowercase)           { report('GPL-2.0-or-later with Bison-exception-2.2', 'dependency_2') }
  let(:violation_gpl_with_bison_lowercase) { violation('GPL-2.0-or-later with Bison-exception-2.2', 'dependency_2') }

  # ---------------------------------------------------------------------------
  # Parenthesised WITH expression
  # ---------------------------------------------------------------------------

  let(:gpl_with_bison_parenthesised) do
    report('(GPL-2.0-or-later WITH Bison-exception-2.2)', 'dependency_3')
  end

  let(:violation_gpl_with_bison_parenthesised) do
    violation('(GPL-2.0-or-later WITH Bison-exception-2.2)', 'dependency_3')
  end

  # ---------------------------------------------------------------------------
  # WITH expression mixed with a plain-name entry
  # ---------------------------------------------------------------------------

  let(:with_with_plain_mit) do
    [
      *report('GPL-2.0-or-later WITH Bison-exception-2.2', 'dependency_1'),
      ['MIT', 'MIT License', 'dependency_4']
    ]
  end

  let(:violation_mit) { violation('MIT License', 'dependency_4') }
  let(:violation_with_with_plain_mit) do
    violation('GPL-2.0-or-later WITH Bison-exception-2.2', 'dependency_1').merge(
      violation('MIT License', 'dependency_4'))
  end

  # ---------------------------------------------------------------------------
  # Multiple WITH expression entries
  # ---------------------------------------------------------------------------

  let(:gpl_with_bison_and_gpl_with_classpath) do
    [
      *report('GPL-2.0-or-later WITH Bison-exception-2.2', 'dependency_1'),
      *report('GPL-2.0-or-later WITH Classpath-exception-2.0', 'dependency_6')
    ]
  end

  let(:violation_gpl_with_classpath) { violation('GPL-2.0-or-later WITH Classpath-exception-2.0', 'dependency_6') }
  let(:violation_gpl_with_bison_and_gpl_with_classpath) do
    violation('GPL-2.0-or-later WITH Bison-exception-2.2', 'dependency_1').merge(
      violation('GPL-2.0-or-later WITH Classpath-exception-2.0', 'dependency_6'))
  end

  # ---------------------------------------------------------------------------
  # WITH expression mixed with AND/OR
  # ---------------------------------------------------------------------------

  let(:with_and_or_expression) do
    report('GPL-2.0-or-later WITH Bison-exception-2.2 AND MIT', 'dependency_5')
  end

  let(:violation_with_and_or_expression) do
    violation('GPL-2.0-or-later WITH Bison-exception-2.2 AND MIT', 'dependency_5')
  end

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_allowed_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Base license allowed -> no violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | nil

    # -------------------------------------------------------------------------
    # Base license not allowed -> violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['MIT License'] | ref(:violation_gpl_with_bison)

    # -------------------------------------------------------------------------
    # detected: violation when the expression exists in the target branch and base is not allowed
    # -------------------------------------------------------------------------

    ref(:gpl_with_bison) | ref(:empty_report) | ['detected']       | ['MIT License'] | ref(:violation_gpl_with_bison)
    ref(:empty_report)   | ref(:gpl_with_bison) | ['detected']     | ['MIT License'] | nil

    # -------------------------------------------------------------------------
    # newly_detected: no violation when the expression already exists in the target branch
    # -------------------------------------------------------------------------

    ref(:gpl_with_bison) | ref(:gpl_with_bison) | ['newly_detected'] | ['MIT License'] | nil

    # -------------------------------------------------------------------------
    # Both states combined
    # -------------------------------------------------------------------------

    ref(:gpl_with_bison) | ref(:gpl_with_bison) | %w[newly_detected detected] | ['MIT License'] | ref(:violation_gpl_with_bison)

    # -------------------------------------------------------------------------
    # Exception identifier alone in the allowlist does NOT permit the expression
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['Bison-exception-2.2'] | ref(:violation_gpl_with_bison)

    # -------------------------------------------------------------------------
    # Full expression string in the allowlist permits it (case-sensitive)
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['GPL-2.0-or-later WITH Bison-exception-2.2'] | nil
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['GPL-2.0-or-later with Bison-exception-2.2'] | ref(:violation_gpl_with_bison)

    # -------------------------------------------------------------------------
    # Multiple WITH expression entries: each evaluated independently
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['GNU General Public License v2.0 or later']          | nil
    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['GPL-2.0-or-later WITH Bison-exception-2.2']         | ref(:violation_gpl_with_classpath)
    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['GPL-2.0-or-later WITH Classpath-exception-2.0'] | ref(:violation_gpl_with_bison)
    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['MIT License'] | ref(:violation_gpl_with_bison_and_gpl_with_classpath)

    # -------------------------------------------------------------------------
    # Lowercase "with" operator
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison_lowercase) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | nil
    ref(:empty_report) | ref(:gpl_with_bison_lowercase) | ['newly_detected'] | ['MIT License']                              | ref(:violation_gpl_with_bison_lowercase)

    # -------------------------------------------------------------------------
    # Parenthesised WITH expression
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison_parenthesised) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | nil
    ref(:empty_report) | ref(:gpl_with_bison_parenthesised) | ['newly_detected'] | ['MIT License']                              | ref(:violation_gpl_with_bison_parenthesised)

    # -------------------------------------------------------------------------
    # WITH expression mixed with a plain-name entry: each evaluated independently
    # -------------------------------------------------------------------------

    # Both allowed
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['GNU General Public License v2.0 or later', 'MIT License'] | nil

    # WITH base not allowed; plain entry allowed
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['MIT License']                              | ref(:violation_gpl_with_bison)

    # WITH base allowed; plain entry not allowed
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_mit)

    # Neither allowed
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License']        | ref(:violation_with_with_plain_mit)

    # -------------------------------------------------------------------------
    # WITH expression mixed with AND/OR
    # -------------------------------------------------------------------------

    # WITH base allowed AND MIT allowed -> no violation (AND requires all children allowed)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['GNU General Public License v2.0 or later', 'MIT License'] | nil

    # WITH base allowed but MIT not allowed -> violation (AND child not allowed)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_with_and_or_expression)

    # MIT allowed but WITH base not allowed -> violation (AND child not allowed)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['MIT License'] | ref(:violation_with_and_or_expression)

    # Full WITH expression in allowlist but MIT not allowed -> violation (AND child not allowed)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['GPL-2.0-or-later WITH Bison-exception-2.2'] | ref(:violation_with_and_or_expression)

    ref(:with_and_or_expression) | ref(:empty_report) | ['detected']       | ['GNU General Public License v2.0 or later', 'MIT License'] | nil
    ref(:with_and_or_expression) | ref(:empty_report) | ['detected']       | ['MIT License']                                             | ref(:violation_with_and_or_expression)
    ref(:empty_report)           | ref(:with_and_or_expression) | ['detected'] | ['MIT License']                                         | nil
    ref(:with_and_or_expression) | ref(:with_and_or_expression) | %w[newly_detected detected] | ['MIT License'] | ref(:violation_with_and_or_expression)
  end
  # rubocop:enable Layout/LineLength
end
