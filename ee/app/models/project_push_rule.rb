# frozen_string_literal: true

class ProjectPushRule < ApplicationRecord
  include PushRuleable

  belongs_to :project, optional: false

  delegate :organization, to: :project

  def available?(feature_sym, **)
    project.licensed_feature_available?(feature_sym)
  end

  def global?
    false
  end
end
