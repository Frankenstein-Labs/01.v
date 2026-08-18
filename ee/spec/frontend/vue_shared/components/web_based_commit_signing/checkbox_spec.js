import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormCheckbox, GlAlert } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import WebBasedCommitSigningCheckbox from 'ee/vue_shared/components/web_based_commit_signing/checkbox.vue';
import GroupInheritancePopover from '~/vue_shared/components/settings/group_inheritance_popover.vue';
import getWebBasedCommitSigningQuery from 'ee/graphql_shared/queries/web_based_commit_signing.query.graphql';
import updateGroupWebBasedCommitSigningMutation from 'ee/graphql_shared/mutations/update_group_web_based_commit_signing.mutation.graphql';
import updateProjectWebBasedCommitSigningMutation from 'ee/graphql_shared/mutations/update_project_web_based_commit_signing.mutation.graphql';
import {
  groupQueryResponse,
  projectQueryResponse,
  groupMutationSuccessResponse,
  projectMutationSuccessResponse,
  projectMutationErrorResponse,
} from './mock_data';

jest.mock('~/sentry/sentry_browser_wrapper', () => ({
  captureException: jest.fn(),
}));

Vue.use(VueApollo);

describe('WebBasedCommitSigningCheckbox', () => {
  let wrapper;
  let fakeApollo;

  const defaultProps = {
    hasGroupPermissions: false,
    groupSettingsRepositoryPath: '/groups/my-group/-/settings/repository',
    isGroupLevel: false,
    fullPath: 'gitlab-org/gitlab-test',
  };

  const createComponent = (props = {}, queryHandler, mutationHandler) => {
    const isGroupLevel = props.isGroupLevel || false;
    const defaultQueryHandler =
      queryHandler ||
      jest
        .fn()
        .mockResolvedValue(
          isGroupLevel ? groupQueryResponse(false) : projectQueryResponse(false, false),
        );
    const defaultGroupMutationHandler = jest.fn().mockResolvedValue(groupMutationSuccessResponse());
    const defaultProjectMutationHandler = jest
      .fn()
      .mockResolvedValue(projectMutationSuccessResponse());

    fakeApollo = createMockApollo([
      [getWebBasedCommitSigningQuery, defaultQueryHandler],
      [updateGroupWebBasedCommitSigningMutation, mutationHandler || defaultGroupMutationHandler],
      [
        updateProjectWebBasedCommitSigningMutation,
        mutationHandler || defaultProjectMutationHandler,
      ],
    ]);

    wrapper = shallowMount(WebBasedCommitSigningCheckbox, {
      apolloProvider: fakeApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GroupInheritancePopover);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('basic rendering', () => {
    it('renders the checkbox component', () => {
      expect(findCheckbox().exists()).toBe(true);
      expect(findCheckbox().text()).toContain('Sign web-based commits');
      expect(findCheckbox().text()).toContain(
        'Automatically sign commits made through the web interface.',
      );
      expect(findCheckbox().props('id')).toBe('web-based-commit-signing-checkbox');
    });

    it('does not render alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe.each`
    scenario                             | projectEnabled | groupEnabled | expectedChecked | expectedDisabled | showsPopover
    ${'both settings false'}             | ${false}       | ${false}     | ${false}        | ${false}         | ${false}
    ${'project enabled, group disabled'} | ${true}        | ${false}     | ${true}         | ${false}         | ${false}
    ${'group enabled (inheritance)'}     | ${false}       | ${true}      | ${true}         | ${true}          | ${true}
  `(
    'when used on project level - $scenario',
    ({ projectEnabled, groupEnabled, expectedChecked, expectedDisabled, showsPopover }) => {
      beforeEach(async () => {
        createComponent(
          {},
          jest.fn().mockResolvedValue(projectQueryResponse(projectEnabled, groupEnabled)),
        );
        await waitForPromises();
      });

      it(`is ${expectedChecked ? 'checked' : 'unchecked'} and ${expectedDisabled ? 'disabled' : 'enabled'}`, () => {
        expect(findCheckbox().props('checked')).toBe(expectedChecked);
        expect(findCheckbox().props('disabled')).toBe(expectedDisabled);
      });

      it(`${showsPopover ? 'renders' : 'does not render'} popover`, () => {
        expect(findPopover().exists()).toBe(showsPopover);
      });
    },
  );

  describe('when used on group level', () => {
    describe('loading state', () => {
      it('is disabled while query is loading', async () => {
        createComponent(
          { isGroupLevel: true },
          jest.fn().mockResolvedValue(groupQueryResponse(false)),
        );

        expect(findCheckbox().props('disabled')).toBe(true);

        await waitForPromises();

        expect(findCheckbox().props('disabled')).toBe(false);
      });
    });

    describe('when group setting is false', () => {
      beforeEach(async () => {
        createComponent(
          { isGroupLevel: true },
          jest.fn().mockResolvedValue(groupQueryResponse(false)),
        );
        await waitForPromises();
      });

      it('is unchecked', () => {
        expect(findCheckbox().props('checked')).toBe(false);
      });

      it('updates internal state when checkbox changes', async () => {
        await findCheckbox().vm.$emit('change', true);
        expect(findCheckbox().props('checked')).toBe(true);
      });

      it('does not render popover', () => {
        expect(findPopover().exists()).toBe(false);
      });
    });
  });

  describe.each`
    level        | isGroupLevel | fullPath                    | queryResponse                               | successResponse
    ${'project'} | ${false}     | ${'gitlab-org/gitlab-test'} | ${() => projectQueryResponse(false, false)} | ${projectMutationSuccessResponse()}
    ${'group'}   | ${true}      | ${'flightjs'}               | ${() => groupQueryResponse(false)}          | ${groupMutationSuccessResponse()}
  `(
    'mutation tests for $level level',
    ({ level, isGroupLevel, fullPath, queryResponse, successResponse }) => {
      let mutationHandler;

      describe('when mutation succeeds', () => {
        beforeEach(async () => {
          mutationHandler = jest.fn().mockResolvedValue(successResponse);
          createComponent(
            { isGroupLevel, fullPath },
            jest.fn().mockResolvedValue(queryResponse()),
            mutationHandler,
          );
          await waitForPromises();
        });

        it('updates the checkbox value when enabling', async () => {
          expect(findCheckbox().props('checked')).toBe(false);

          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(findCheckbox().props('checked')).toBe(true);
        });

        it('shows "enabled" toast when enabling', async () => {
          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Web-based commit signing enabled');
        });

        it('shows "disabled" toast when disabling', async () => {
          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();
          wrapper.vm.$toast.show.mockClear();

          const disableResponse = isGroupLevel
            ? groupMutationSuccessResponse(false)
            : projectMutationSuccessResponse(false);

          mutationHandler.mockResolvedValue(disableResponse);

          await findCheckbox().vm.$emit('change', false);
          await waitForPromises();

          expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Web-based commit signing disabled');
        });
      });

      describe.each`
        failureType             | mockResponse                                                 | expectedError
        ${'rejected promise'}   | ${() => Promise.reject(new Error('Mutation failed'))}        | ${'Mutation failed'}
        ${'errors in response'} | ${() => projectMutationErrorResponse(['Permission denied'])} | ${'Permission denied'}
      `('when mutation fails with $failureType', ({ failureType, mockResponse, expectedError }) => {
        if (failureType === 'errors in response' && level !== 'project') {
          return;
        }

        beforeEach(async () => {
          mutationHandler = jest.fn().mockImplementation(mockResponse);
          createComponent(
            { isGroupLevel, fullPath },
            jest.fn().mockResolvedValue(queryResponse()),
            mutationHandler,
          );
          await waitForPromises();
        });

        it('reverts the checkbox value and shows error', async () => {
          expect(findCheckbox().props('checked')).toBe(false);

          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(findCheckbox().props('checked')).toBe(false);
          expect(findAlert().exists()).toBe(true);
          expect(findAlert().text()).toBe(expectedError);
        });

        it('calls Sentry', async () => {
          captureException.mockClear();

          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(captureException).toHaveBeenCalledWith({
            error: expect.any(Error),
            component: 'WebBasedCommitSigningCheckbox',
          });
        });
      });
    },
  );

  describe('when query fails to load', () => {
    beforeEach(async () => {
      createComponent({ isGroupLevel: true }, jest.fn().mockRejectedValue('error'));
      await waitForPromises();
    });

    it('renders alert with error message', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toBe('An error occurred while loading the settings.');
    });

    it('should capture exceptions in Sentry', () => {
      expect(captureException).toHaveBeenCalledWith({
        error: expect.any(Error),
        component: 'WebBasedCommitSigningCheckbox',
      });
    });

    it('dismisses error when alert is dismissed', async () => {
      await findAlert().vm.$emit('dismiss');
      expect(wrapper.vm.errorMessage).toBe('');
    });
  });
});
