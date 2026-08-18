# frozen_string_literal: true

# This model represents a merge train with many Merge Request 'Cars' for a projects branch
module MergeTrains
  class Train
    include Gitlab::Utils::StrongMemoize

    STATUSES = {
      active: 'active',
      completed: 'completed'
    }.freeze

    def self.all_for_project(project)
      MergeTrains::Car
      .active
      .where(target_project: project)
      .select('DISTINCT ON (target_branch) *')
      .map(&:train)
    end

    # Consider moving to finder
    def self.all_for(project, status: nil, target_branch: [])
      cars = MergeTrains::Car
                 .where(target_project: project)
      cars = cars.where(target_branch: target_branch) if target_branch.present?

      case status
      when :completed, STATUSES[:completed]
        cars = cars.where.not(target_branch: cars.active.select(:target_branch))
      when :active, STATUSES[:active]
        cars = cars.active
      end

      cars
        .select('DISTINCT ON (merge_trains.target_branch) *')
        .map(&:train)
    end

    def self.project_using_ff?(project)
      project.merge_trains_enabled? &&
        project.ff_merge_must_be_possible?
    end

    attr_reader :project_id, :target_branch

    def initialize(project_id, branch)
      @project_id = project_id
      @target_branch = branch
    end

    def project
      Project.find_by_id(project_id)
    end
    strong_memoize_attr :project

    def refresh_async
      MergeTrains::RefreshWorker.perform_async(project_id, target_branch)
    end

    def first_active_car
      all_active_cars.first
    end

    def car_count
      all_active_cars.count
    end

    def active?
      all_active_cars.any?
    end

    def completed?
      !active?
    end

    def sha_exists_in_history?(newrev, limit: 20)
      MergeRequest.where(id: completed_cars(limit: limit).select(:merge_request_id))
        .where(
          'merge_commit_sha = ? OR in_progress_merge_commit_sha = ? OR squash_commit_sha = ? OR merged_commit_sha = ?',
          newrev, newrev, newrev, newrev)
        .exists?
    end

    def all_active_cars(limit: nil)
      persisted_cars.active.by_id.limit(limit)
    end

    def all_active_cars_indexed(limit: nil)
      all_active_cars(limit: limit).indexed
    end

    def completed_cars(limit: nil)
      persisted_cars.complete.by_id(:desc).limit(limit)
    end

    def refreshable_cars(limit: nil)
      persisted_cars.refreshable.by_id.limit(limit)
    end

    private

    def persisted_cars
      MergeTrains::Car.for_target(project_id, target_branch).with_partition_aware_preload
    end
  end
end
