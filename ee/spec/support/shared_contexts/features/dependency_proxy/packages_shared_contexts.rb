# frozen_string_literal: true

RSpec.shared_context 'with a wrong etag returned' do
  before do
    allow_next_instance_of(::DependencyProxy::Packages::VerifyPackageFileEtagService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.error(message: '', reason: :wrong_etag))
    end
  end
end

RSpec.shared_context 'with no etag returned' do
  before do
    allow_next_instance_of(::DependencyProxy::Packages::VerifyPackageFileEtagService) do |service|
      allow(service).to receive(:execute).and_return(ServiceResponse.error(message: '', reason: :no_etag))
    end
  end
end
