# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Concerns::YamlDefinitionParser, feature_category: :ai_agents do
  let(:test_class) do
    Class.new do
      include Ai::Catalog::Concerns::YamlDefinitionParser

      attr_accessor :params, :current_user, :project

      def initialize(params, current_user, project)
        @params = params
        @current_user = current_user
        @project = project
      end

      def error(message)
        { error: message }
      end
    end
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  subject(:parser) { test_class.new({}, user, project) }

  describe '#use_object_storage_for_yaml_definition?' do
    context 'when ai_catalog_yaml_object_storage feature flag is disabled' do
      before do
        stub_feature_flags(ai_catalog_yaml_object_storage: false)
      end

      it 'returns false' do
        expect(parser.send(:use_object_storage_for_yaml_definition?)).to be(false)
      end
    end

    context 'when ai_catalog_yaml_object_storage feature flag is enabled for project' do
      before do
        stub_feature_flags(ai_catalog_yaml_object_storage: project)
      end

      it 'returns true' do
        expect(parser.send(:use_object_storage_for_yaml_definition?)).to be(true)
      end
    end
  end
end
