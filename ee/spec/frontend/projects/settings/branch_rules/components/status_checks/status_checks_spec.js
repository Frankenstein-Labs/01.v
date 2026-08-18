import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import StatusCheckDeleteModal from 'ee/projects/settings/branch_rules/components/status_checks/status_checks_delete_modal.vue';
import StatusChecks from 'ee/projects/settings/branch_rules/components/status_checks/status_checks.vue';
import branchRulesQuery from 'ee_else_ce/projects/settings/branch_rules/queries/branch_rules_details.query.graphql';
import createStatusCheckMutation from 'ee/projects/settings/branch_rules/mutations/external_status_check_create.mutation.graphql';
import updateStatusCheckMutation from 'ee/projects/settings/branch_rules/mutations/external_status_check_update.mutation.graphql';
import deleteStatusCheckMutation from 'ee/projects/settings/branch_rules/mutations/external_status_check_delete.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  statusCheckCreateSuccessResponse,
  statusCheckUpdateSuccessResponse,
  statusCheckDeleteSuccessResponse,
  statusCheckCreateNameTakenResponse,
  statusChecksRulesMock,
  branchProtectionsMockResponse,
} from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;
  let fakeApollo;

  const createComponent = ({
    createStatusCheckHandler,
    updateStatusCheckHandler,
    deleteStatusCheckHandler,
  } = {}) => {
    fakeApollo = createMockApollo([
      [createStatusCheckMutation, createStatusCheckHandler],
      [updateStatusCheckMutation, updateStatusCheckHandler],
      [deleteStatusCheckMutation, deleteStatusCheckHandler],
    ]);

    fakeApollo.clients.defaultClient.cache.writeQuery({
      query: branchRulesQuery,
      variables: {
        projectPath: 'gid://gitlab/Project/1',
        isAllBranchesRule: false,
      },
      ...branchProtectionsMockResponse,
    });

    wrapper = shallowMountExtended(StatusChecks, {
      apolloProvider: fakeApollo,
      propsData: {
        branchRuleId: 'gid://gitlab/Projects/BranchRule/1',
        projectPath: 'gid://gitlab/Project/1',
        isAllBranchesRule: false,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  afterEach(() => {
    fakeApollo = null;
  });

  const findStatusChecksTable = () => wrapper.findComponentByTestId('status-checks-table');
  const findStatusChecksDrawer = () => wrapper.findComponentByTestId('status-checks-drawer');
  const findStatusCheckRemovalModal = () => wrapper.findComponent(StatusCheckDeleteModal);

  it('should render loading state', async () => {
    createComponent();
    expect(findStatusChecksDrawer().props('isLoading')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    await nextTick();
    expect(findStatusChecksDrawer().props('isLoading')).toBe(true);
  });

  it('should create status check successfully', () => {
    const createStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckCreateSuccessResponse);
    createComponent({ createStatusCheckHandler: createStatusCheckHandlerSuccess });
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    expect(createStatusCheckHandlerSuccess).toHaveBeenCalled();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should close drawer and show a toast when no changes are made', () => {
    const updateStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckUpdateSuccessResponse);
    createComponent({ updateStatusCheckHandler: updateStatusCheckHandlerSuccess });
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('open-status-check-drawer', statusChecksRulesMock[0]);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      { ...statusChecksRulesMock[0] },
      'update',
    );
    expect(updateStatusCheckHandlerSuccess).not.toHaveBeenCalled();
    expect(wrapper.vm.$toast.show).toHaveBeenCalledWith(
      'No changes were made to the status check.',
    );
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should update status check successfully', () => {
    const updateStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckUpdateSuccessResponse);
    createComponent({ updateStatusCheckHandler: updateStatusCheckHandlerSuccess });
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('open-status-check-drawer', statusChecksRulesMock[0]);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      { ...statusChecksRulesMock[0], name: 'new name' },
      'update',
    );
    expect(updateStatusCheckHandlerSuccess).toHaveBeenCalled();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should update status check when only sharedSecret changes', () => {
    const updateStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckUpdateSuccessResponse);
    createComponent({ updateStatusCheckHandler: updateStatusCheckHandlerSuccess });
    findStatusChecksTable().vm.$emit('open-status-check-drawer', statusChecksRulesMock[0]);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      { ...statusChecksRulesMock[0], sharedSecret: 'new-secret' },
      'update',
    );
    expect(updateStatusCheckHandlerSuccess).toHaveBeenCalledWith({
      branchRuleId: 'gid://gitlab/Projects/BranchRule/1',
      ...statusChecksRulesMock[0],
      sharedSecret: 'new-secret',
    });
  });

  it('should delete status check successfully', () => {
    const deleteStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckDeleteSuccessResponse);
    createComponent({ deleteStatusCheckHandler: deleteStatusCheckHandlerSuccess });
    findStatusCheckRemovalModal().vm.$emit('delete-status-check', statusChecksRulesMock[0]);
    expect(deleteStatusCheckHandlerSuccess).toHaveBeenCalled();
  });

  it('should pass the server validation errors down', async () => {
    const createStatusCheckHandlerValidationError = jest
      .fn()
      .mockResolvedValue(statusCheckCreateNameTakenResponse);
    createComponent({ createStatusCheckHandler: createStatusCheckHandlerValidationError });
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    await waitForPromises();
    expect(createStatusCheckHandlerValidationError).toHaveBeenCalled();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should close the drawer when close event is emitted', async () => {
    createComponent();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksTable().vm.$emit('open-status-check-drawer');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(true);
    findStatusChecksDrawer().vm.$emit('close-status-check-drawer');
    await nextTick();
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
  });

  it('should show an error alert when request fails', async () => {
    const createStatusCheckHandlerError = jest
      .fn()
      .mockRejectedValue(new Error('Something went wrong'));
    createComponent({ createStatusCheckHandler: createStatusCheckHandlerError });
    expect(findStatusChecksDrawer().props('isOpen')).toBe(false);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    expect(createStatusCheckHandlerError).toHaveBeenCalled();
    await waitForPromises();
    expect(wrapper.vm.errorMessages).toContain('Unable to create status check. Please try again.');
  });

  it('emits a tracking event when a status check is added', async () => {
    const createStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckCreateSuccessResponse);
    createComponent({ createStatusCheckHandler: createStatusCheckHandlerSuccess });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      statusChecksRulesMock[0],
      'create',
    );
    await waitForPromises();
    expect(trackEventSpy).toHaveBeenCalledWith('change_status_checks', {
      label: 'branch_rule_details',
    });
  });

  it('emits a tracking event when a status check is updated', async () => {
    const updateStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckUpdateSuccessResponse);
    createComponent({ updateStatusCheckHandler: updateStatusCheckHandlerSuccess });
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    findStatusChecksTable().vm.$emit('open-status-check-drawer', statusChecksRulesMock[0]);
    findStatusChecksDrawer().vm.$emit(
      'save-status-check-change',
      { ...statusChecksRulesMock[0], name: 'new name' },
      'update',
    );
    await waitForPromises();
    expect(trackEventSpy).toHaveBeenCalledWith('change_status_checks', {
      label: 'branch_rule_details',
    });
  });

  it('emits a tracking event when a status check is deleted', async () => {
    const deleteStatusCheckHandlerSuccess = jest
      .fn()
      .mockResolvedValue(statusCheckDeleteSuccessResponse);
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
    createComponent({ deleteStatusCheckHandler: deleteStatusCheckHandlerSuccess });
    findStatusCheckRemovalModal().vm.$emit('delete-status-check', statusChecksRulesMock[0]);
    await waitForPromises();
    expect(trackEventSpy).toHaveBeenCalledWith('change_status_checks', {
      label: 'branch_rule_details',
    });
  });
});
