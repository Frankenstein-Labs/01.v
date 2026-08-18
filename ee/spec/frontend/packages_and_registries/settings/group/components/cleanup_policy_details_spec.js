import { GlButton, GlIcon, GlSprintf, GlBadge, GlAlert } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CleanupPolicyDetails from 'ee_component/packages_and_registries/settings/group/components/cleanup_policy_details.vue';

import getVirtualRegistriesCleanupPolicyDetails from 'ee/packages_and_registries/settings/group/graphql/queries/get_virtual_registries_cleanup_policy_details.query.graphql';
import { groupVirtualRegistriesCleanupPolicyMock } from '../mock_data';

Vue.use(VueApollo);

describe('CleanupPolicyDetails', () => {
  let wrapper;
  let apolloProvider;
  let cleanupPolicyQueryHandler;

  const groupPath = 'testFullPath';
  const virtualRegistryCleanupPolicyPath =
    '/groups/foo/-/settings/packages_and_registries/cleanup_policies';

  const createComponent = ({
    mockQueryResponse = groupVirtualRegistriesCleanupPolicyMock(),
    mockQueryError = null,
    virtualRegistriesSettingEnabled = true,
  } = {}) => {
    if (mockQueryError) {
      cleanupPolicyQueryHandler = jest.fn().mockRejectedValue(mockQueryError);
    } else {
      cleanupPolicyQueryHandler = jest.fn().mockResolvedValue(mockQueryResponse);
    }

    const requestHandlers = [[getVirtualRegistriesCleanupPolicyDetails, cleanupPolicyQueryHandler]];

    apolloProvider = createMockApollo(requestHandlers);

    wrapper = shallowMountExtended(CleanupPolicyDetails, {
      apolloProvider,
      provide: {
        groupPath,
        virtualRegistryCleanupPolicyPath,
      },
      propsData: {
        virtualRegistriesSettingEnabled,
      },
      stubs: {
        CrudComponent,
        GlSprintf,
      },
    });
  };

  const findCleanupPolicyDetails = () => wrapper.findComponent(CrudComponent);
  const findEditButton = () => wrapper.findComponent(GlButton);
  const findStatusBadge = () => wrapper.findComponent(GlBadge);
  const findNextRun = () => wrapper.findByTestId('cleanup-policy-next-run');
  const findLastRun = () => wrapper.findByTestId('cleanup-policy-last-run');
  const findAlertByVariant = (variant) =>
    wrapper.findAllComponents(GlAlert).wrappers.find((w) => w.props('variant') === variant) || {
      exists: () => false,
    };

  const findFailureAlert = () => findAlertByVariant('danger');
  const findFetchErrorAlert = () => findAlertByVariant('warning');

  describe('when a cleanup policy does not exist', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock(null),
      });
      await waitForPromises();
    });

    it('renders the default state', () => {
      expect(findCleanupPolicyDetails().text()).toContain(
        'No cleanup rule yet. Define when caches should be deleted to save space.',
      );
      expect(findEditButton().text()).toContain('Set policy');
      expect(findEditButton().attributes('href')).toBe(virtualRegistryCleanupPolicyPath);
    });
  });

  describe('when a cleanup policy exists', () => {
    describe('when the cleanup policy is enabled', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            lastRunDeletedSize: 1572864,
          }),
        });
        await waitForPromises();
      });

      it('renders the enabled badge with correct text', () => {
        expect(findStatusBadge().text()).toBe('Enabled');
        expect(findStatusBadge().attributes('variant')).toBe('success');
        expect(findStatusBadge().attributes('icon')).toBe('check-circle-filled');
      });

      it('renders next run at', () => {
        expect(findNextRun().text()).toMatchInterpolatedText(
          'Next cleanup: December 15, 2025 at 10:00:00 AM GMT.',
        );
      });

      it('renders last run at with deleted size', () => {
        expect(findLastRun().text()).toMatchInterpolatedText(
          'Last cleanup: December 1, 2025 at 10:00:00 AM GMT. 1.50 MiB saved.',
        );
      });
    });

    describe('when the cleanup policy is disabled', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            enabled: false,
          }),
        });
        await waitForPromises();
      });

      it('renders the disabled badge with correct text', () => {
        expect(findStatusBadge().text()).toBe('Disabled');
        expect(findStatusBadge().attributes('variant')).toBe('neutral');
        expect(findStatusBadge().attributes('icon')).toBe('cancel');
      });

      it('renders next run at as Not scheduled', () => {
        expect(findNextRun().text()).toMatchInterpolatedText('Next cleanup: Not scheduled.');
      });

      it('renders last run at', () => {
        expect(findLastRun().text()).toMatchInterpolatedText(
          'Last cleanup: December 1, 2025 at 10:00:00 AM GMT. 1.00 KiB saved.',
        );
      });
    });

    describe('when the cleanup policy is running', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            status: 'RUNNING',
          }),
        });
        await waitForPromises();
      });

      it('renders the running badge with correct text', () => {
        expect(findStatusBadge().text()).toBe('Running');
        expect(findStatusBadge().attributes('variant')).toBe('info');
        expect(findStatusBadge().attributes('icon')).toBe('status_running');
      });

      it('renders next run at as Running', () => {
        expect(findNextRun().text()).toMatchInterpolatedText('Next cleanup: Running.');
      });

      it('renders last run at', () => {
        expect(findLastRun().text()).toMatchInterpolatedText(
          'Last cleanup: December 1, 2025 at 10:00:00 AM GMT. 1.00 KiB saved.',
        );
      });
    });

    describe('when the cleanup policy has failed', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            status: 'FAILED',
            failureMessage: 'Connection timeout while accessing upstream registry',
          }),
        });
        await waitForPromises();
      });

      it('renders failure alert with error message', () => {
        expect(findFailureAlert().exists()).toBe(true);
        expect(findFailureAlert().props('variant')).toBe('danger');
        expect(findFailureAlert().props('dismissible')).toBe(false);
        expect(findFailureAlert().text()).toContain(
          'Cache cleanup failed. No cache entries were removed.',
        );
        expect(findFailureAlert().text()).toContain(
          'Connection timeout while accessing upstream registry',
        );
      });

      it('renders error message with last run date', () => {
        expect(findLastRun().text()).toMatchInterpolatedText(
          'Last cleanup: Cleanup failed on December 1, 2025 at 10:00:00 AM GMT.',
        );
      });

      it('renders error icon in last cleanup field', () => {
        const errorIcon = findLastRun().findComponent(GlIcon);
        expect(errorIcon.exists()).toBe(true);
        expect(errorIcon.props('name')).toBe('error');
      });
    });

    describe('when the cleanup policy has failed without a failure message', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            status: 'FAILED',
            failureMessage: null,
          }),
        });
        await waitForPromises();
      });

      it('renders failure alert without detailed message', () => {
        expect(findFailureAlert().exists()).toBe(true);
        expect(findFailureAlert().text()).toEqual(
          'Cache cleanup failed. No cache entries were removed.',
        );
      });
    });

    describe('when the cleanup policy has never run', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            lastRunAt: null,
          }),
        });
        await waitForPromises();
      });

      it('renders last run as "Never run"', () => {
        expect(findLastRun().text()).toMatchInterpolatedText('Last cleanup: Never run.');
      });

      it('does not render deleted size', () => {
        expect(findLastRun().text()).not.toContain('saved');
      });
    });

    describe('when last cleanup deleted no data', () => {
      beforeEach(async () => {
        createComponent({
          mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
            lastRunDeletedSize: 0,
          }),
        });
        await waitForPromises();
      });

      it('does not render deleted size when zero', () => {
        expect(findLastRun().text()).not.toContain('saved');
      });
    });

    describe('cadences', () => {
      describe.each`
        cadence | expectedText
        ${1}    | ${'every day'}
        ${7}    | ${'every week'}
        ${14}   | ${'every two weeks'}
        ${30}   | ${'every month'}
        ${90}   | ${'every three months'}
      `('when cadence is $cadence', ({ cadence, expectedText }) => {
        beforeEach(async () => {
          createComponent({
            mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
              cadence,
            }),
          });
          await waitForPromises();
        });

        it(`renders "Runs ${expectedText}"`, () => {
          expect(wrapper.text()).toContain(`Runs ${expectedText}`);
        });
      });
    });

    describe('email notifications', () => {
      describe.each`
        notifyOnSuccess | notifyOnFailure | expectedText
        ${true}         | ${true}         | ${'Send email notifications when cleanup runs and if cleanup fails'}
        ${true}         | ${false}        | ${'Send email notifications when cleanup runs'}
        ${false}        | ${true}         | ${'Send email notifications if cleanup fails'}
        ${false}        | ${false}        | ${''}
      `(
        'when notifyOnSuccess is $notifyOnSuccess and notifyOnFailure is $notifyOnFailure',
        ({ notifyOnSuccess, notifyOnFailure, expectedText }) => {
          beforeEach(async () => {
            createComponent({
              mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
                notifyOnSuccess,
                notifyOnFailure,
              }),
            });
            await waitForPromises();
          });

          if (expectedText) {
            it(`renders "${expectedText}"`, () => {
              expect(wrapper.findByTestId('cleanup-policy-rules').text()).toContain(expectedText);
            });
          } else {
            it('does not render email notification text', () => {
              const rulesText = wrapper.findByTestId('cleanup-policy-rules').text();
              expect(rulesText).not.toContain('Send email notifications');
            });
          }
        },
      );
    });

    describe('removes cache not accessed in details', () => {
      describe('when keepNDaysAfterDownload is 1', () => {
        beforeEach(async () => {
          createComponent({
            mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
              keepNDaysAfterDownload: 1,
            }),
          });
          await waitForPromises();
        });

        it('renders singular form without the number', () => {
          expect(wrapper.findByTestId('cleanup-policy-rules').text()).toContain(
            'Delete caches not accessed in the last day',
          );
        });
      });

      describe('when keepNDaysAfterDownload is greater than 1', () => {
        beforeEach(async () => {
          createComponent({
            mockQueryResponse: groupVirtualRegistriesCleanupPolicyMock({
              keepNDaysAfterDownload: 35,
            }),
          });
          await waitForPromises();
        });

        it('renders plural form with the number', () => {
          expect(wrapper.findByTestId('cleanup-policy-rules').text()).toContain(
            'Delete caches not accessed in the last 35 days',
          );
        });
      });
    });
  });

  describe('edit policy button', () => {
    describe('when virtual registries setting is enabled', () => {
      beforeEach(async () => {
        createComponent({
          virtualRegistriesSettingEnabled: true,
        });
        await waitForPromises();
      });

      it('is not disabled', () => {
        expect(findEditButton().props('disabled')).toBe(false);
      });
    });

    describe('when virtual registries setting is disabled', () => {
      beforeEach(async () => {
        createComponent({
          virtualRegistriesSettingEnabled: false,
        });
        await waitForPromises();
      });

      it('is disabled', () => {
        expect(findEditButton().props('disabled')).toBe(true);
      });
    });
  });

  describe('when GraphQL query fails', () => {
    beforeEach(async () => {
      createComponent({
        mockQueryError: new Error('GraphQL error'),
      });
      await waitForPromises();
    });

    it('renders the fetch error alert', () => {
      expect(findFetchErrorAlert().exists()).toBe(true);
      expect(findFetchErrorAlert().props('variant')).toBe('warning');
      expect(findFetchErrorAlert().props('dismissible')).toBe(false);
      expect(findFetchErrorAlert().text()).toBe(
        'Something went wrong while fetching the cleanup policy.',
      );
    });

    it('does not render cleanup policy content', () => {
      expect(findStatusBadge().exists()).toBe(false);
      expect(findNextRun().exists()).toBe(false);
      expect(findLastRun().exists()).toBe(false);
      expect(wrapper.findByTestId('cleanup-policy-rules').exists()).toBe(false);
    });

    it('does not render the cleanup failure alert', () => {
      expect(findFailureAlert().exists()).toBe(false);
    });

    it('still renders the edit button', () => {
      expect(findEditButton().exists()).toBe(true);
    });
  });
});
