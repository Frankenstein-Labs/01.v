# frozen_string_literal: true

RSpec.shared_examples 'code suggestion prompt' do
  describe '#request_params' do
    it 'returns expected request params' do
      expect(subject.request_params.except(:prompt)).to eq(request_params.except(:prompt))
      expect(subject.request_params[:prompt].gsub(/\s+/, " ")).to eq(request_params[:prompt].gsub(/\s+/, " "))
    end
  end
end
