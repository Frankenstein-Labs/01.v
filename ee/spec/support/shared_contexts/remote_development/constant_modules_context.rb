# frozen_string_literal: true

RSpec.shared_context "with constant modules" do
  # NOTE: These are all implemented as methods rather than `let` declarations, so they are able to be
  #       used in let_it_be scopes. They don't work when used in arguments in `it_behaves_like`, though...

  # @return [Module<RemoteDevelopment::Files>]
  def files_module
    RemoteDevelopment::Files
  end

  # @return [Module<RemoteDevelopment::WorkspaceOperations::States>]
  def states_module
    RemoteDevelopment::WorkspaceOperations::States
  end

  # @return [Module<RemoteDevelopment::WorkspaceOperations::Create::CreateConstants>]
  def create_constants_module
    RemoteDevelopment::WorkspaceOperations::Create::CreateConstants
  end

  # @return [Module<RemoteDevelopment::WorkspaceOperations::WorkspaceOperationsConstants>]
  def workspace_operations_constants_module
    RemoteDevelopment::WorkspaceOperations::WorkspaceOperationsConstants
  end
end
