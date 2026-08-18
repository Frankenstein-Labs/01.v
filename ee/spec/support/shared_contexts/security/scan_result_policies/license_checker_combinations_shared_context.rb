# frozen_string_literal: true

RSpec.shared_context 'for license_checker' do
  using RSpec::Parameterized::TableSyntax

  where(:target_branch, :pipeline_branch, :states, :policy_license, :policy_state, :violated_licenses) do
    ref(:case1) | ref(:case2) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation1)
    ref(:case1) | ref(:case2) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | ref(:violation1)
    ref(:case2) | ref(:case3) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | nil
    ref(:case2) | ref(:case3) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | nil
    ref(:case3) | ref(:case4) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation3)
    ref(:case3) | ref(:case4) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | ref(:violation3)
    ref(:case4) | ref(:case5) | ['newly_detected'] | ['GPL v3', 'GNU 3'] | :denied | nil
    ref(:case4) | ref(:case5) | ['newly_detected'] | [nil, 'GNU 3'] | :denied | nil
    ref(:case1) | ref(:case2) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | nil
    ref(:case1) | ref(:case2) | ['detected'] | [nil, 'GNU 3'] | :denied | nil
    ref(:case2) | ref(:case3) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation1)
    ref(:case2) | ref(:case3) | ['detected'] | [nil, 'GNU 3'] | :denied | ref(:violation1)
    ref(:case3) | ref(:case4) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation1)
    ref(:case3) | ref(:case4) | ['detected'] | [nil, 'GNU 3'] | :denied | ref(:violation1)
    ref(:case4) | ref(:case5) | ['detected'] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation2)
    ref(:case4) | ref(:case5) | ['detected'] | [nil, 'GNU 3'] | :denied | ref(:violation2)
    ref(:case4) | ref(:case5) | %w[newly_detected detected] | ['GPL v3', 'GNU 3'] | :denied | ref(:violation2)

    ref(:case1) | ref(:case2) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation1)
    ref(:case1) | ref(:case2) | ['newly_detected'] | [nil, 'MIT License'] | :allowed | ref(:violation1)
    ref(:case2) | ref(:case3) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | nil
    ref(:case3) | ref(:case4) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation3)
    ref(:case3) | ref(:case4) | ['newly_detected'] | [nil, 'MIT License'] | :allowed | ref(:violation3)
    ref(:case4) | ref(:case5) | ['newly_detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation4)
    ref(:case4) | ref(:case5) | ['newly_detected'] | [nil, 'MIT License'] | :allowed | ref(:violation4)
    ref(:case1) | ref(:case2) | ['detected'] | ['MIT', 'MIT License'] | :allowed | nil
    ref(:case1) | ref(:case2) | ['detected'] | [nil, 'MIT License'] | :allowed | nil
    ref(:case2) | ref(:case3) | ['detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation1)
    ref(:case2) | ref(:case3) | ['detected'] | [nil, 'MIT License'] | :allowed | ref(:violation1)
    ref(:case3) | ref(:case4) | ['detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation1)
    ref(:case3) | ref(:case4) | ['detected'] | [nil, 'MIT License'] | :allowed | ref(:violation1)
    ref(:case4) | ref(:case5) | ['detected'] | ['MIT', 'MIT License'] | :allowed | ref(:violation2)
    ref(:case4) | ref(:case5) | ['detected'] | [nil, 'MIT License'] | :allowed | ref(:violation2)
    ref(:case4) | ref(:case5) | %w[newly_detected detected] | ['MIT', 'MIT License'] | :allowed | ref(:violation4)

    ref(:case2) | ref(:case2) | ['detected'] | [nil, 'GNU 3'] | :allowed | nil
  end
end
