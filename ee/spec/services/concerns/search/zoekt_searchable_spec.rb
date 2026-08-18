# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::ZoektSearchable, feature_category: :global_search do
  let(:subject_class) do
    Class.new do
      include Search::ZoektSearchable
    end
  end

  let(:class_instance) { subject_class.new }

  describe '#search_level' do
    it 'raise NotImplementedError' do
      expect { class_instance.search_level }.to raise_error(NotImplementedError)
    end
  end

  describe '#zoekt_node_available_for_search?' do
    context 'when there are no nodes available for search' do
      it 'returns false' do
        allow(class_instance).to receive_message_chain(:zoekt_nodes, :exists?).and_return(false)

        expect(class_instance.zoekt_node_available_for_search?).to be_falsey
      end
    end

    context 'when there are nodes available for search' do
      it 'returns true' do
        allow(class_instance).to receive_message_chain(:zoekt_nodes, :exists?).and_return(true)

        expect(class_instance.zoekt_node_available_for_search?).to be_truthy
      end
    end
  end
end
