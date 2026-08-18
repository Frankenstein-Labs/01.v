# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker WITH operator' do
  include_context 'for license_expression_checker'

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
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_denied_names, :violated_licenses) do
    # -------------------------------------------------------------------------
    # Base license denied triggers a violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison)
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['MIT License'] | nil

    # detected: violation when the expression exists in the target branch report
    ref(:gpl_with_bison) | ref(:empty_report) | ['detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison)
    ref(:empty_report) | ref(:gpl_with_bison) | ['detected'] | ['GNU General Public License v2.0 or later'] | nil

    # newly_detected: no violation when the expression already exists in the target branch
    ref(:gpl_with_bison) | ref(:gpl_with_bison) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | nil

    # both states combined
    ref(:gpl_with_bison) | ref(:gpl_with_bison) | %w[newly_detected detected] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison)

    # -------------------------------------------------------------------------
    # Denying only the exception identifier is NOT a violation
    # (exceptions cannot be denied independently; only the base license or full expression matters)
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['Bison-exception-2.2'] | nil

    # -------------------------------------------------------------------------
    # Full expression denied triggers a violation (case-sensitive)
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['GPL-2.0-or-later WITH Bison-exception-2.2'] | ref(:violation_gpl_with_bison)
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | ['GPL-2.0-or-later with Bison-exception-2.2'] | nil

    # -------------------------------------------------------------------------
    # Multiple WITH expression entries: each is evaluated independently
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison_and_gpl_with_classpath)
    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['GPL-2.0-or-later WITH Bison-exception-2.2'] | ref(:violation_gpl_with_bison)
    ref(:empty_report) | ref(:gpl_with_bison_and_gpl_with_classpath) | ['newly_detected'] | ['GPL-2.0-or-later WITH Classpath-exception-2.0'] | ref(:violation_gpl_with_classpath)

    # -------------------------------------------------------------------------
    # Lowercase "with" operator still matches base license; unrelated denial yields no violation
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison_lowercase) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison_lowercase)
    ref(:empty_report) | ref(:gpl_with_bison_lowercase) | ['newly_detected'] | ['MIT License'] | nil

    # -------------------------------------------------------------------------
    # Parenthesised WITH expression: outer parentheses are handled by the parser
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:gpl_with_bison_parenthesised) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison_parenthesised)
    ref(:empty_report) | ref(:gpl_with_bison_parenthesised) | ['newly_detected'] | ['MIT License'] | nil

    # -------------------------------------------------------------------------
    # WITH expression mixed with a plain-name entry
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['GNU General Public License v2.0 or later', 'MIT License'] | ref(:violation_with_with_plain_mit)
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_gpl_with_bison)
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['MIT License'] | ref(:violation_mit)
    ref(:empty_report) | ref(:with_with_plain_mit) | ['newly_detected'] | ['BSD 2-Clause "Simplified" License'] | nil

    # -------------------------------------------------------------------------
    # WITH expression mixed with AND/OR
    # -------------------------------------------------------------------------

    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_with_and_or_expression)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['MIT License'] | ref(:violation_with_and_or_expression)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['GNU General Public License v2.0 or later', 'MIT License'] | ref(:violation_with_and_or_expression)
    ref(:empty_report) | ref(:with_and_or_expression) | ['newly_detected'] | ['GPL-2.0-or-later WITH Bison-exception-2.2'] | ref(:violation_with_and_or_expression)
    ref(:with_and_or_expression) | ref(:empty_report) | ['detected'] | ['GNU General Public License v2.0 or later'] | ref(:violation_with_and_or_expression)
    ref(:empty_report) | ref(:with_and_or_expression) | ['detected'] | ['GNU General Public License v2.0 or later'] | nil
    ref(:with_and_or_expression) | ref(:with_and_or_expression) | %w[newly_detected detected] | ['GNU General Public License v2.0 or later'] | ref(:violation_with_and_or_expression)
  end
  # rubocop:enable Layout/LineLength
end
