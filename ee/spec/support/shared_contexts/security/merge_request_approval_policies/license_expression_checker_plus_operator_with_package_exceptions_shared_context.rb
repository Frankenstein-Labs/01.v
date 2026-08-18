# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker PLUS operator with package exceptions' do
  include_context 'for license_expression_checker with package exceptions'

  let(:cddl_1_plus)           { report('CDDL-1.0+', dependency: 'foo') }
  let(:violation_cddl_1_plus) { violation('CDDL-1.0+', 'foo') }

  let(:foo_excluded) { ['pkg:gem/foo'] }
  let(:except_cddl)  { { 'CDDL-1.0' => foo_excluded } }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_state, :policy_names, :excluded_packages, :violated_licenses) do
    # PLUS base covered by the denied policy; excepting the dependency clears it.
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | :denied | ['CDDL-1.0'] | ref(:except_cddl) | nil

    # Base denied, no exception -> violation.
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | :denied | ['CDDL-1.0'] | ref(:no_exceptions) | ref(:violation_cddl_1_plus)

    # Allowlist: base allowed; carving the dependency out makes it a violation.
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | :allowed | ['CDDL-1.0'] | ref(:except_cddl) | ref(:violation_cddl_1_plus)

    # Allowlist: base allowed, no carve-out -> compliant.
    ref(:empty_report) | ref(:cddl_1_plus) | ['newly_detected'] | :allowed | ['CDDL-1.0'] | ref(:no_exceptions) | nil
  end
  # rubocop:enable Layout/LineLength
end
