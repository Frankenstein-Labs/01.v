# frozen_string_literal: true

module MergeTrainsHelpers
  def create_merge_request_on_train(
    project:, author: nil, target_branch: 'master', source_branch: 'feature',
    status: :idle)
    merge_request = create(:merge_request, :on_train,
      source_project: project,
      target_project: project,
      target_branch: target_branch,
      source_branch: source_branch,
      author: author || create(:user),
      status: MergeTrains::Car.state_machines[:status].states[status].value)

    merge_request.merge_train_car.update!(pipeline: create(:ci_pipeline, user: author, project: project))

    merge_request
  end
end
