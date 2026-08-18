# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker WITH operator with package exceptions' do
  include_context 'for license_expression_checker with package exceptions'

  let(:gpl_with_bison)           { report('GPL-2.0-or-later WITH Bison-exception-2.2', dependency: 'foo') }
  let(:violation_gpl_with_bison) { violation('GPL-2.0-or-later WITH Bison-exception-2.2', 'foo') }

  let(:foo_excluded)           { ['pkg:gem/foo'] }
  let(:except_gpl_base)        { { 'GNU General Public License v2.0 or later' => foo_excluded } }
  let(:except_full_expression) { { 'GPL-2.0-or-later WITH Bison-exception-2.2' => foo_excluded } }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_state, :policy_names, :excluded_packages, :violated_licenses) do
    # Base license denied; excepting the dependency under the base license clears it.
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | :denied | ['GNU General Public License v2.0 or later'] | ref(:except_gpl_base) | nil

    # Base license denied, no exception -> violation.
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | :denied | ['GNU General Public License v2.0 or later'] | ref(:no_exceptions) | ref(:violation_gpl_with_bison)

    # Full expression denied; excepting the dependency under the full expression clears it.
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | :denied | ['GPL-2.0-or-later WITH Bison-exception-2.2'] | ref(:except_full_expression) | nil

    # Allowlist: base license allowed; carving the dependency out makes it a violation.
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | :allowed | ['GNU General Public License v2.0 or later'] | ref(:except_gpl_base) | ref(:violation_gpl_with_bison)

    # Allowlist: base license allowed, no carve-out -> compliant.
    ref(:empty_report) | ref(:gpl_with_bison) | ['newly_detected'] | :allowed | ['GNU General Public License v2.0 or later'] | ref(:no_exceptions) | nil
  end
  # rubocop:enable Layout/LineLength
end
