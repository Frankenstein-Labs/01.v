# frozen_string_literal: true

RSpec.shared_context 'for denied_licenses_checker without package exceptions' do
  let(:case1) { [] }
  let(:case2) { [['GPL v3', 'GNU 3', 'A']] }
  let(:case3) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B']] }
  let(:case4) { [['GPL v3', 'GNU 3', 'A'], ['MIT', 'MIT License', 'B'], ['GPL v3', 'GNU 3', 'C']] }
  let(:case5) do
    [
      ['GPL v3', 'GNU 3', 'A'],
      ['MIT', 'MIT License', 'B'],
      ['GPL v3', 'GNU 3', 'C'],
      ['Apache 2', 'Apache License 2', 'D']
    ]
  end

  let(:violation1) { { 'GNU 3' => %w[A] } }
  let(:violation2) { { 'GNU 3' => %w[A C] } }
  let(:violation3) { { 'GNU 3' => %w[C] } }
  let(:violation4) { { 'Apache License 2' => %w[D] } }
  let(:violation5) { { 'Apache License 2' => %w[D], 'GNU 3' => %w[A C] } }

  using RSpec::Parameterized::TableSyntax

  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_license, :policy_state,
    :violated_licenses) do
    ref(:case1) | ref(:case2) | ['newly_detected'] | 'GNU 3' | :denied | ref(:violation1)
    ref(:case2) | ref(:case3) | ['newly_detected'] | 'GNU 3' | :denied | nil
    ref(:case3) | ref(:case4) | ['newly_detected'] | 'GNU 3' | :denied | ref(:violation3)
    ref(:case4) | ref(:case5) | ['newly_detected'] | 'GNU 3' | :denied | nil
    ref(:case1) | ref(:case2) | ['detected'] | 'GNU 3' | :denied | nil
    ref(:case2) | ref(:case3) | ['detected'] | 'GNU 3' | :denied | ref(:violation1)
    ref(:case3) | ref(:case4) | ['detected'] | 'GNU 3' | :denied | ref(:violation1)
    ref(:case4) | ref(:case5) | ['detected'] | 'GNU 3' | :denied | ref(:violation2)
    ref(:case4) | ref(:case5) | %w[newly_detected detected] | 'GNU 3' | :denied | ref(:violation2)
    ref(:case1) | ref(:case2) | ['newly_detected'] | 'MIT License' | :allowed | ref(:violation1)
    ref(:case2) | ref(:case3) | ['newly_detected'] | 'MIT License' | :allowed | nil
    ref(:case3) | ref(:case4) | ['newly_detected'] | 'MIT License' | :allowed | ref(:violation3)
    ref(:case4) | ref(:case5) | ['newly_detected'] | 'MIT License' | :allowed | ref(:violation4)
    ref(:case1) | ref(:case2) | ['detected'] | 'MIT License' | :allowed | nil
    ref(:case2) | ref(:case3) | ['detected'] | 'MIT License' | :allowed | ref(:violation1)
    ref(:case3) | ref(:case4) | ['detected'] | 'MIT License' | :allowed | ref(:violation1)
    ref(:case4) | ref(:case5) | ['detected'] | 'MIT License' | :allowed | ref(:violation2)
    ref(:case4) | ref(:case5) | %w[newly_detected detected] | 'MIT License' | :allowed | ref(:violation5)
    ref(:case2) | ref(:case2) | ['detected'] | 'GNU 3' | :allowed | nil
  end
end

RSpec.shared_context 'for denied_licenses_checker with package exceptions' do
  let(:empty_report) { [] }
  let(:mit_bundler_2_6_2_report) { [['MIT', 'MIT License', 'gem', 'bundler', '2.6.2']] }
  let(:mit_bundler_1_5_1_report) { [['MIT', 'MIT License', 'gem', 'bundler', '1.5.1']] }
  let(:mit_rails_8_0_1_report) { [['MIT', 'MIT License', 'gem', 'rails', '8.0.1']] }

  let(:mit_bundler_violation) { { 'MIT License' => %w[bundler] } }
  let(:mit_rails_violation) { { 'MIT License' => %w[rails] } }
  let(:mit_rails_bundler_violation) { { 'MIT License' => %w[rails bundler] } }

  let(:bundler_excluded) { ['pkg:gem/bundler'] }
  let(:bundler_2_6_2_excluded) { ['pkg:gem/bundler@2.6.2'] }
  let(:rails_8_0_1_excluded) { ['pkg:gem/rails@8.0.1'] }
  let(:i18n_excluded) { ['pkg:gem/i18n'] }

  using RSpec::Parameterized::TableSyntax

  where(:target_branch_licenses, :pipeline_branch_licenses, :states, :policy_license, :policy_state,
    :excluded_packages, :violated_licenses) do
    # license allowed but package excluded in all versions
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | ['newly_detected'] | 'MIT License' | :allowed |
      ref(:bundler_excluded) | ref(:mit_bundler_violation)
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_excluded) | ref(:mit_bundler_violation)

    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | ['newly_detected'] | 'MIT License' | :allowed |
      ref(:bundler_excluded) | ref(:mit_bundler_violation)
    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_excluded) | ref(:mit_bundler_violation)

    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :allowed |
      ref(:bundler_excluded) | ref(:mit_bundler_violation)
    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_excluded) | ref(:mit_bundler_violation)

    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :allowed |
      ref(:bundler_excluded) | ref(:mit_bundler_violation)
    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_excluded) | ref(:mit_bundler_violation)

    # license allowed but package excluded in a specific version
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | ['newly_detected'] | 'MIT License' | :allowed |
      ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)

    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | ['newly_detected'] | 'MIT License' | :allowed |
      ref(:bundler_2_6_2_excluded) | nil
    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_2_6_2_excluded) | nil

    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :allowed |
      ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)
    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)

    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :allowed |
      ref(:bundler_2_6_2_excluded) | nil
    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_2_6_2_excluded) | nil

    # license denied but package excluded in all versions
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | ['newly_detected'] | 'MIT License' | :denied |
      ref(:bundler_excluded) | nil
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_excluded) | nil

    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | ['newly_detected'] | 'MIT License' | :denied |
      ref(:bundler_excluded) | nil
    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_excluded) | nil

    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :denied |
      ref(:bundler_excluded) | nil
    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_excluded) | nil

    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :denied |
      ref(:bundler_excluded) | nil
    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_excluded) | nil

    # license denied but package excluded in a specific version
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | ['newly_detected'] | 'MIT License' | :denied |
      ref(:bundler_2_6_2_excluded) | nil
    ref(:empty_report) | ref(:mit_bundler_2_6_2_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_2_6_2_excluded) | nil

    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | ['newly_detected'] | 'MIT License' | :denied |
      ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)
    ref(:empty_report) | ref(:mit_bundler_1_5_1_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)

    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :denied |
      ref(:bundler_2_6_2_excluded) | nil
    ref(:mit_bundler_2_6_2_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_2_6_2_excluded) | nil

    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | ['detected'] | 'MIT License' | :denied |
      ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)
    ref(:mit_bundler_1_5_1_report) | ref(:empty_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_2_6_2_excluded) | ref(:mit_bundler_violation)

    # No new license, but new dependency with denied license with excluded package
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | ['newly_detected'] | 'MIT License' | :denied |
      ref(:rails_8_0_1_excluded) | nil

    # No new license, new dependency with denied license with excluded package
    # and detected license without package exception
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:rails_8_0_1_excluded) | ref(:mit_bundler_violation)

    # No new license, but new dependency with allowed license with excluded package
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | ['newly_detected'] | 'MIT License' | :allowed |
      ref(:rails_8_0_1_excluded) | ref(:mit_rails_violation)
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:rails_8_0_1_excluded) | ref(:mit_rails_violation)

    # No new license, but new dependency with denied license and package is not part of the exceptions
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | ['newly_detected'] | 'MIT License' | :denied |
      ref(:bundler_2_6_2_excluded) | ref(:mit_rails_violation)

    # No new license, but new dependency with denied license and package is not part of the exceptions
    # and detected violated license
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_2_6_2_excluded) | ref(:mit_rails_bundler_violation)

    # No new license, but new dependency with allowed license and package is not part of the exceptions
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | ['newly_detected'] | 'MIT License' | :allowed |
      ref(:bundler_2_6_2_excluded) | nil
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | %w[newly_detected
      detected] | 'MIT License' | :allowed | ref(:bundler_2_6_2_excluded) | nil

    # detected violation, newly detected violation with package exception
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:bundler_excluded) | ref(:mit_rails_violation)

    # detected and newly detected violation without package exception
    ref(:mit_bundler_1_5_1_report) | ref(:mit_rails_8_0_1_report) | %w[newly_detected
      detected] | 'MIT License' | :denied | ref(:i18n_excluded) | ref(:mit_rails_bundler_violation)
  end
end
