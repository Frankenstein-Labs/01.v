# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::AchievementUploadReplicator, feature_category: :geo_replication do
  let(:model_record) { create(:geo_achievement_upload) }

  include_examples 'a blob replicator with a read-only replicable model'
  include_examples 'a blob replicator with upload replicator behavior'
end
