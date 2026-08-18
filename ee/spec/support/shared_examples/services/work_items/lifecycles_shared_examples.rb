# frozen_string_literal: true

RSpec.shared_examples 'lifecycle service does not create custom lifecycle' do
  it 'does not create custom lifecycle' do
    expect { result }.not_to change { WorkItems::Statuses::Custom::Lifecycle.count }
  end

  it { expect { result }.not_to trigger_internal_events }
end

RSpec.shared_examples 'lifecycle service returns validation error' do
  it 'returns validation error' do
    expect(result).to be_error
    expect(result.message).to include(expected_error_message)
  end
end

RSpec.shared_examples 'lifecycle service creates custom lifecycle' do
  it 'creates custom lifecycle' do
    # We cannot use .by(1) here because when no custom lifecycle existed before,
    # the create service will convert the system-defined lifecycle to a custom one and
    # create 2 lifecycles in total.
    expect { result }.to change { WorkItems::Statuses::Custom::Lifecycle.count }

    expect(WorkItems::Statuses::Custom::Lifecycle.last).to eq(lifecycle)

    expect(lifecycle).to have_attributes(
      name: lifecycle_name,
      namespace: group,
      created_by: user
    )
  end
end
