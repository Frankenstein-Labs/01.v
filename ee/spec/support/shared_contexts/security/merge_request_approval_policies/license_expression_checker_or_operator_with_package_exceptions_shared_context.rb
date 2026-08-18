# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker OR operator with package exceptions' do
  include_context 'for license_expression_checker with package exceptions'

  let(:mit_or_apache)           { report('MIT OR Apache-2.0', dependency: 'foo') }
  let(:violation_mit_or_apache) { violation('MIT OR Apache-2.0', 'foo') }

  let(:foo_excluded)          { ['pkg:gem/foo'] }
  let(:except_mit)            { { 'MIT License' => foo_excluded } }
  let(:except_mit_and_apache) { { 'MIT License' => foo_excluded, 'Apache License 2.0' => foo_excluded } }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_state, :policy_names, :excluded_packages, :violated_licenses) do
    # OR is a violation only when ALL components are denied. Excepting the dependency
    # under one denied component turns that component into a safe choice -> cleared.
    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | :denied | ['MIT License', 'Apache License 2.0'] | ref(:except_mit) | nil

    # No exception, every component denied -> violation.
    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | :denied | ['MIT License', 'Apache License 2.0'] | ref(:no_exceptions) | ref(:violation_mit_or_apache)

    # Excepting under every denied component also clears it.
    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | :denied | ['MIT License', 'Apache License 2.0'] | ref(:except_mit_and_apache) | nil

    # Allowlist OR is allowed when ANY component is allowed, so carving the dependency
    # out of one component still leaves the other as a safe choice -> compliant.
    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | :allowed | ['MIT License', 'Apache License 2.0'] | ref(:except_mit) | nil

    # Carving the dependency out of every allowed component makes it a violation.
    ref(:empty_report) | ref(:mit_or_apache) | ['newly_detected'] | :allowed | ['MIT License', 'Apache License 2.0'] | ref(:except_mit_and_apache) | ref(:violation_mit_or_apache)
  end
  # rubocop:enable Layout/LineLength
end
