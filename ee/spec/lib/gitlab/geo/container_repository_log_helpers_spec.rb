# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::ContainerRepositoryLogHelpers, feature_category: :geo_replication do
  before do
    stub_const('FakeContainerRepositoryLogHelpersConsumer', Class.new)

    FakeContainerRepositoryLogHelpersConsumer.class_eval do
      include Gitlab::Geo::ContainerRepositoryLogHelpers

      attr_reader :container_repository

      def initialize(container_repository)
        @container_repository = container_repository
      end

      def execute
        log_info('Test message')
      end
    end
  end

  let_it_be(:project) { create(:project) }
  let_it_be(:container_repository) { create(:container_repository, project: project) }

  subject(:consumer) { FakeContainerRepositoryLogHelpersConsumer.new(container_repository) }

  describe '#extra_log_data' do
    it 'includes project and container repository fields' do
      expect(consumer.extra_log_data).to include(
        project_id: project.id,
        project_path: project.full_path,
        container_repository_name: container_repository.name
      )
    end
  end

  describe 'logging methods' do
    it 'includes extra_log_data in log_info call' do
      expect(Gitlab::Geo::Logger).to receive(:info).with(
        hash_including(
          project_id: project.id,
          project_path: project.full_path,
          container_repository_name: container_repository.name
        )
      )

      consumer.execute
    end
  end
end
