# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mcp::Tools::Concerns::ResourceFinder, feature_category: :mcp_server do
  let(:test_class) do
    Class.new do
      include Mcp::Tools::Concerns::ResourceFinder

      attr_accessor :current_user

      def initialize(user = nil)
        @current_user = user
      end

      def test_find_work_item_in_parent(parent, iid)
        find_work_item_in_parent!(parent, iid)
      end
    end
  end

  describe '#find_work_item_in_parent!' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group, developers: user) }
    let_it_be(:group_work_item) { create(:work_item, :epic, namespace: group) }

    let(:work_item_iid) { group_work_item.iid }
    let(:service) { test_class.new(user) }

    subject(:find_work_item_in_parent) { service.test_find_work_item_in_parent(group, work_item_iid) }

    context 'with group parent (epic)' do
      before do
        stub_licensed_features(epics: true)
      end

      it 'finds work item by iid' do
        is_expected.to eq(group_work_item)
      end

      context 'when work item not found' do
        let(:work_item_iid) { non_existing_record_iid }

        it 'raises error' do
          expect { find_work_item_in_parent }
            .to raise_error(ArgumentError, "Work item ##{work_item_iid} not found")
        end
      end
    end
  end
end
