# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::Latest::ApplicationInstanceProxy, feature_category: :global_search do
  let_it_be(:project) { create(:project, :in_subgroup) }
  let(:group) { project.group }
  let(:target) { project.repository }
  let(:included_class) { Elasticsearch::Model::Proxy::InstanceMethodsProxy }

  subject(:proxy) { included_class.new(target) }

  describe '#es_parent' do
    let(:target) { create(:merge_request) }

    it 'includes project id' do
      expect(proxy.es_parent).to eq("project_#{target.project.id}")
    end
  end

  describe '#namespace_ancestry' do
    it 'returns the full ancestry' do
      expect(proxy.namespace_ancestry).to eq("#{group.parent.id}-#{group.id}-")
    end
  end
end
