# frozen_string_literal: true

RSpec.shared_examples_for 'excludes archived and projects pending deletion' do
  it 'excludes archived projects' do
    policy_project.update!(archived: true)

    expect(suggestions).to exclude(policy_project)
  end

  it 'excludes projects pending deletion' do
    policy_project.update!(pending_delete: true)

    expect(suggestions).to exclude(policy_project)
  end
end
