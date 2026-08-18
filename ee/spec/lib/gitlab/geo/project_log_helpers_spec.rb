# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::ProjectLogHelpers, feature_category: :geo_replication do
  before do
    stub_const('FakeProjectLogHelpersConsumer', Class.new)

    FakeProjectLogHelpersConsumer.class_eval do
      include Gitlab::Geo::ProjectLogHelpers

      attr_reader :project

      def initialize(project)
        @project = project
      end
    end
  end

  let_it_be(:project) { create(:project) }

  describe '#base_log_data' do
    subject(:consumer) { FakeProjectLogHelpersConsumer.new(project) }

    it 'includes project fields in log data' do
      log_data = consumer.base_log_data('Test message')

      expect(log_data).to include(
        project_id: project.id,
        project_path: project.full_path,
        storage_version: project.storage_version
      )
    end

    context 'when project is nil' do
      subject(:consumer) { FakeProjectLogHelpersConsumer.new(nil) }

      it 'does not include project fields in log data' do
        log_data = consumer.base_log_data('Test message')

        expect(log_data).not_to include(:project_id, :project_path, :storage_version)
      end
    end
  end
end
