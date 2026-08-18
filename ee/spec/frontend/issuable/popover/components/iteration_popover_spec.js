import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlBadge, GlIcon, GlSkeletonLoader, GlProgressBar } from '@gitlab/ui';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';

import iterationQuery from '~/issuable/popover/queries/iteration.query.graphql';
import IterationPopover from 'ee_component/issuable/popover/components/iteration_popover.vue';
import TimeboxStatusBadge from 'ee_component/iterations/components/timebox_status_badge.vue';

describe('Iteration Popover', () => {
  const mockIterationeResponse = {
    data: {
      iteration: {
        __typename: 'Iteration',
        id: 'gid://gitlab/Iteration/1',
        title: null,
        startDate: '2025-07-29',
        dueDate: '2025-08-30',
        state: 'current',
        webUrl: 'https://gdk.test:3000/gitlab/test/-/iterations/1',
        iterationCadence: {
          id: 'gid://gitlab/Iterations::Cadence/1',
          title: 'Ab repellat fugit sunt optio temporibus eius id.',
        },
        report: {
          stats: {
            total: {
              count: 2,
            },
            complete: {
              count: 1,
            },
          },
        },
        group: {
          id: 'gid://gitlab/Group/1',
          fullPath: 'gitlab-org',
        },
      },
    },
  };

  const mockIteration = mockIterationeResponse.data.iteration;
  let wrapper;

  Vue.use(VueApollo);

  const mountComponent = ({
    queryResponse = jest.fn().mockResolvedValue(mockIterationeResponse),
  } = {}) => {
    wrapper = shallowMountExtended(IterationPopover, {
      apolloProvider: createMockApollo([[iterationQuery, queryResponse]]),
      propsData: {
        target: document.createElement('a'),
        iterationId: '1',
        namespacePath: 'test/space',
        cachedTitle: 'Jul 29 – Aug 30, 2025',
      },
      stubs: {
        TimeboxStatusBadge,
      },
    });
  };

  const findCadenceTitle = () => wrapper.findByTestId('iteration-cadence-title');
  const findStateBadge = () => wrapper.findComponent(TimeboxStatusBadge);
  const findIterationIcon = () => wrapper.findComponent(GlIcon);
  const findIterationLabel = () => wrapper.findByTestId('iteration-label');
  const findIterationTimeframe = () => wrapper.findByTestId('iteration-timeframe');
  const findIterationTitle = () => wrapper.findByTestId('iteration-title');
  const findIterationProgress = () => wrapper.findByTestId('iteration-progress');
  const findIterationPath = () => wrapper.findByTestId('iteration-path');

  describe('while popover is loading', () => {
    beforeEach(() => {
      mountComponent();
    });

    it('shows icon and text', () => {
      expect(findIterationLabel().exists()).toBe(true);
      expect(findIterationIcon().exists()).toBe(true);
      expect(findIterationIcon().props('name')).toBe('iteration');
      expect(findIterationLabel().text()).toBe('Iteration');
    });

    it('shows skeleton-loader', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('shows cached cadence title', () => {
      expect(findCadenceTitle().exists()).toBe(true);
      expect(findCadenceTitle().text()).toContain('Jul 29');
      expect(findCadenceTitle().text()).toContain('Aug 30, 2025');
    });

    it('does not show state badge, timeframe, iteration title, or iteration path', () => {
      expect(findStateBadge().exists()).toBe(false);
      expect(findIterationTimeframe().exists()).toBe(false);
      expect(findIterationTitle().exists()).toBe(false);
      expect(findIterationPath().exists()).toBe(false);
    });

    it('does not show state badge or dates', () => {
      expect(findStateBadge().exists()).toBe(false);
      expect(findIterationTimeframe().exists()).toBe(false);
    });
  });

  describe('when popover contents are loaded', () => {
    // Set current date to 10th April 2024
    useFakeDate(2024, 3, 10);

    beforeEach(async () => {
      mountComponent();

      await waitForPromises();
    });

    it('shows cadence title', () => {
      expect(findCadenceTitle().text()).toBe('Ab repellat fugit sunt optio temporibus eius id.');
    });

    it('shows timeframe as a link', () => {
      expect(findIterationTimeframe().exists()).toBe(true);
      expect(findIterationTimeframe().attributes('href')).toBe(
        'https://gdk.test:3000/gitlab/test/-/iterations/1',
      );
    });

    it.each`
      state         | expectedVariant | expectedText
      ${'closed'}   | ${'danger'}     | ${'Closed'}
      ${'current'}  | ${'success'}    | ${'Open'}
      ${'upcoming'} | ${'neutral'}    | ${'Upcoming'}
    `(
      'shows state badge with variant $expectedVariant and text $expectedText',
      async ({ state, expectedVariant, expectedText }) => {
        mountComponent({
          queryResponse: jest.fn().mockResolvedValue({
            data: {
              iteration: {
                ...mockIteration,
                state,
              },
            },
          }),
        });

        await waitForPromises();

        expect(findStateBadge().props('state')).toBe(state);
        expect(findStateBadge().findComponent(GlBadge).props('variant')).toBe(expectedVariant);
        expect(findStateBadge().findComponent(GlBadge).text()).toBe(expectedText);
      },
    );

    it.each`
      startDate       | dueDate         | expectedText
      ${'2024-04-01'} | ${'2024-04-30'} | ${'Apr 1 – 30, 2024'}
      ${'2025-07-29'} | ${'2025-08-30'} | ${'Jul 29 – Aug 30, 2025'}
    `(
      'shows timeframe text when startDate is $startDate and dueDate is $dueDate',
      async ({ startDate, dueDate, expectedText }) => {
        mountComponent({
          queryResponse: jest.fn().mockResolvedValue({
            data: {
              iteration: {
                ...mockIteration,
                startDate,
                dueDate,
              },
            },
          }),
        });

        await waitForPromises();

        expect(findIterationTimeframe().text()).toBe(expectedText);
      },
    );

    it('shows progress bar and percentage completion', () => {
      const progressEl = findIterationProgress();
      const progressBar = progressEl.findComponent(GlProgressBar);
      expect(progressBar.attributes()).toMatchObject({
        value: '50',
        variant: 'primary',
      });
      expect(progressEl.find('span').text()).toBe('50% complete');
    });

    it.each`
      description                                                                 | report                                                        | shouldShowProgress
      ${'shows progress when report stats with total and complete are available'} | ${{ stats: { total: { count: 0 }, complete: { count: 0 } } }} | ${true}
      ${'does not show progress when report stats are not available'}             | ${null}                                                       | ${false}
    `('$description', async ({ report, shouldShowProgress }) => {
      mountComponent({
        queryResponse: jest.fn().mockResolvedValue({
          data: {
            iteration: {
              ...mockIteration,
              report,
            },
          },
        }),
      });

      await waitForPromises();

      expect(findIterationProgress().exists()).toBe(shouldShowProgress);
    });

    it('shows iteration group path', () => {
      const pathEl = findIterationPath();
      expect(pathEl.exists()).toBe(true);
      expect(pathEl.findComponent(GlIcon).props('name')).toBe('group');
      expect(pathEl.find('span').text()).toBe('gitlab-org');
    });
  });
});
