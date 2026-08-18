# frozen_string_literal: true

RSpec.shared_examples 'work item mutation with status widget with error' do
  it 'does not update work item and raises error' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(graphql_errors).not_to be_empty
    expect_graphql_errors_to_include(expected_error_message)
  end
end

RSpec.shared_examples 'successful work item mutation with status widget' do
  it 'has current status with system defined status' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    work_item_id = GlobalID.parse(mutation_response['workItem']['id']).model_id.to_i

    current_status = ::WorkItems::Statuses::CurrentStatus.find_by(work_item_id: work_item_id)

    expect(current_status.status).to eq(status)
  end
end

RSpec.shared_examples 'work item status widget mutation rejects invalid inputs' do
  context 'when status gid references non-existing system-defined status' do
    let(:status_gid) { 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/99' }
    let(:expected_error_message) { "Status doesn't exist." }

    it_behaves_like 'work item mutation with status widget with error'
  end

  context 'when status gid references non-existing custom status' do
    let(:status_gid) { "gid://gitlab/WorkItems::Statuses::Custom::Status/#{non_existing_record_id}" }
    let(:expected_error_message) { "Status doesn't exist." }

    it_behaves_like 'work item mutation with status widget with error'
  end
end
