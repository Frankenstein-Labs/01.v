# frozen_string_literal: true

RSpec.shared_context 'for license_expression_checker AND operator with package exceptions' do
  include_context 'for license_expression_checker with package exceptions'

  let(:mit_and_apache)           { report('MIT AND Apache-2.0', dependency: 'foo') }
  let(:violation_mit_and_apache) { violation('MIT AND Apache-2.0', 'foo') }

  let(:foo_excluded)            { ['pkg:gem/foo'] }
  let(:except_mit)              { { 'MIT License' => foo_excluded } }
  let(:except_mit_and_apache)   { { 'MIT License' => foo_excluded, 'Apache License 2.0' => foo_excluded } }

  using RSpec::Parameterized::TableSyntax

  # rubocop:disable Layout/LineLength -- table syntax is clearer on one line
  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_state, :policy_names, :excluded_packages, :violated_licenses) do
    # AND is a violation when ANY component is denied, so a dependency excepted under
    # only one denied component is still a violation through the other component.
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | :denied | ['MIT License', 'Apache License 2.0'] | ref(:except_mit) | ref(:violation_mit_and_apache)

    # Cleared only when the dependency is excepted under every denied component.
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | :denied | ['MIT License', 'Apache License 2.0'] | ref(:except_mit_and_apache) | nil

    # A single denied component cleared by an exception is no longer a violation.
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | :denied | ['MIT License'] | ref(:except_mit) | nil

    # No matching exception leaves the violation intact.
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | :denied | ['MIT License'] | ref(:no_exceptions) | ref(:violation_mit_and_apache)

    # Allowlist AND requires every component allowed, so carving the dependency out of
    # one allowed component makes the whole expression a violation for that dependency.
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | :allowed | ['MIT License', 'Apache License 2.0'] | ref(:except_mit) | ref(:violation_mit_and_apache)

    # No carve-out keeps the fully-allowed expression compliant.
    ref(:empty_report) | ref(:mit_and_apache) | ['newly_detected'] | :allowed | ['MIT License', 'Apache License 2.0'] | ref(:no_exceptions) | nil
  end
  # rubocop:enable Layout/LineLength
end
