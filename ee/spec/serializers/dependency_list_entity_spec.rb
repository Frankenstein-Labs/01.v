# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyListEntity do
  describe '#as_json' do
    let(:entity) do
      described_class.represent(items, pipeline: pipeline, request: request)
    end

    let(:request) { EntityRequest.new(project: project, user: user) }
    let(:collection) { [build_stubbed(:sbom_occurrence)] }
    let(:no_items_status) { :no_dependencies }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted records
    let_it_be(:project) { create(:project, :repository, :private) }
    let_it_be(:developer) { create(:user) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject(:as_json) { entity.as_json }

    before_all do
      project.add_developer(developer)
    end

    context 'with pipeline' do
      let(:user) { developer }
      let(:pipeline) { build_stubbed(:ci_pipeline, :success) }
      let(:job_path) { "/#{project.full_path}/-/pipelines/#{pipeline.id}" }

      context 'with provided items' do
        let(:items) { collection }

        it 'has array of items with status ok' do
          expect(as_json[:dependencies]).to be_kind_of(Array)
          expect(as_json[:report][:status]).to eq(:ok)
          expect(as_json[:report][:job_path]).to eq(job_path)
          expect(as_json[:report][:generated_at]).to eq(pipeline.finished_at)
        end
      end

      context 'with no items' do
        let(:user) { developer }
        let(:items) { [] }

        it 'has empty array of items with status no_items' do
          expect(as_json[:dependencies].length).to eq(0)
          expect(as_json[:report][:status]).to eq(:ok)
          expect(as_json[:report][:job_path]).to eq(job_path)
        end
      end

      context 'without authorized user' do
        let(:user) { build_stubbed(:user) }
        let(:items) { [] }

        it 'does not render report object' do
          expect(as_json[:report]).not_to be_present
        end
      end
    end

    context 'with no pipeline' do
      let(:user) { developer }
      let(:pipeline) { nil }
      let(:items) { collection }

      it 'has an array of items and no report object' do
        expect(as_json[:dependencies]).to be_kind_of(Array)
        expect(as_json[:report]).not_to be_present
      end
    end
  end
end
