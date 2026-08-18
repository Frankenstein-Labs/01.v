import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import DuoReadinessRunnerRow from 'ee/pages/projects/shared/permissions/components/duo_readiness_runner_row.vue';
import runnerAvailableQuery from 'ee/pages/projects/shared/permissions/graphql/duo_workflow_runner_available.query.graphql';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('DuoReadinessRunnerRow', () => {
  let wrapper;

  const projectFullPath = 'g/p';
  const runnersPath = '/g/p/-/settings/ci_cd#js-runners-settings';

  const queryResponse = (available, type = null) => ({
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        duoWorkflowRunnerAvailable: available,
        duoWorkflowUsableRunnerType: type,
      },
    },
  });

  const createComponent = ({
    runnerAvailable = true,
    usableRunnerType = null,
    flowExecutionEnabled = true,
    queryHandler = jest.fn().mockResolvedValue(queryResponse(true, 'instance_type')),
  } = {}) => {
    wrapper = mountExtended(DuoReadinessRunnerRow, {
      apolloProvider: createMockApollo([[runnerAvailableQuery, queryHandler]]),
      propsData: {
        readiness: { runnerAvailable, usableRunnerType, runnersPath },
        flowExecutionEnabled,
        projectFullPath,
      },
    });

    return queryHandler;
  };

  const findRow = () => wrapper.findComponent(DuoReadinessRow);
  const findAction = () => wrapper.findComponentByTestId('runner-row-action');

  describe('when a usable runner exists', () => {
    beforeEach(() => {
      createComponent({ runnerAvailable: true, usableRunnerType: 'group_type' });
    });

    it('is done', () => {
      expect(findRow().props('status')).toBe('done');
      expect(findRow().props('description')).toBe('A runner is available and picking up jobs.');
    });

    it('links to the runners tab holding that runner', () => {
      expect(findAction().text()).toBe('View runners');
      expect(findAction().attributes('href')).toBe(
        '/g/p/-/settings/ci_cd?tab=group#js-runners-settings',
      );
    });

    // A same-tab navigation would discard unsaved changes in the settings form.
    it('opens the runners settings in a new tab', () => {
      expect(findAction().attributes('target')).toBe('_blank');
    });
  });

  describe('when no runner exists and flow execution is off', () => {
    beforeEach(() => {
      createComponent({ runnerAvailable: false, flowExecutionEnabled: false });
    });

    it('is blocked rather than failing', () => {
      expect(findRow().props('status')).toBe('blocked');
      expect(findRow().props('description')).toBe('Needed once flow execution is on.');
      expect(findAction().text()).toBe('Check again');
      expect(findAction().props('disabled')).toBe(true);
    });
  });

  describe('when no runner exists and flow execution is on', () => {
    beforeEach(() => {
      createComponent({ runnerAvailable: false });
    });

    it('is an error offering a re-check', () => {
      expect(findRow().props('status')).toBe('error');
      expect(findRow().props('description')).toBe(
        'No runner this project can use, so flows would never start.',
      );
      expect(findAction().text()).toBe('Check again');
      expect(findAction().props('disabled')).toBe(false);
    });
  });

  describe('Check again', () => {
    describe('when a runner has been registered since the page rendered', () => {
      let queryHandler;

      beforeEach(async () => {
        queryHandler = createComponent({
          runnerAvailable: false,
          queryHandler: jest.fn().mockResolvedValue(queryResponse(true, 'instance_type')),
        });

        findAction().trigger('click');
        await waitForPromises();
      });

      it('updates the row in place', () => {
        expect(queryHandler).toHaveBeenCalledWith({ fullPath: projectFullPath });
        expect(findRow().props('status')).toBe('done');
      });

      it('links to the tab of the runner that satisfied the re-check', () => {
        expect(findAction().text()).toBe('View runners');
        expect(findAction().attributes('href')).toBe(
          '/g/p/-/settings/ci_cd?tab=instance#js-runners-settings',
        );
      });
    });

    describe('when there is still no runner', () => {
      beforeEach(async () => {
        createComponent({
          runnerAvailable: false,
          queryHandler: jest.fn().mockResolvedValue(queryResponse(false)),
        });

        findAction().trigger('click');
        await waitForPromises();
      });

      it('stays in the error state', () => {
        expect(findRow().props('status')).toBe('error');
      });
    });

    describe('while the check is running', () => {
      let queryHandler;

      beforeEach(async () => {
        queryHandler = createComponent({ runnerAvailable: false });

        findAction().trigger('click');
        await nextTick();
      });

      it('shows a loading state on the button', () => {
        expect(findAction().props('loading')).toBe(true);
      });

      it('ignores further clicks', async () => {
        findAction().trigger('click');
        await waitForPromises();

        expect(queryHandler).toHaveBeenCalledTimes(1);
      });
    });

    describe('when the page must not reload', () => {
      it('re-checks without reloading', async () => {
        const reload = jest.fn();
        Object.defineProperty(window, 'location', { value: { reload }, writable: true });
        createComponent({ runnerAvailable: false });

        findAction().trigger('click');
        await waitForPromises();

        expect(reload).not.toHaveBeenCalled();
      });
    });

    describe('when the answer is redacted by authorization', () => {
      beforeEach(async () => {
        createComponent({
          runnerAvailable: false,
          queryHandler: jest.fn().mockResolvedValue(queryResponse(null)),
        });

        findAction().trigger('click');
        await waitForPromises();
      });

      it('alerts instead of reporting no runner', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({
            message:
              'Could not check for a runner. You do not have permission to check this project.',
          }),
        );
        expect(findRow().props('status')).toBe('error');
      });
    });

    describe('when the check fails', () => {
      beforeEach(async () => {
        createComponent({
          runnerAvailable: false,
          queryHandler: jest.fn().mockRejectedValue(new Error('nope')),
        });

        findAction().trigger('click');
        await waitForPromises();
      });

      it('alerts and keeps the current state', () => {
        expect(createAlert).toHaveBeenCalledWith(
          expect.objectContaining({ message: 'Could not check for a runner. Try again.' }),
        );
        expect(findRow().props('status')).toBe('error');
        expect(findAction().props('loading')).toBe(false);
      });
    });
  });
});
