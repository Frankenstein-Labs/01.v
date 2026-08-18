import { GlSkeletonLoader, GlCard } from '@gitlab/ui';
import { merge } from 'lodash-es';
import Vue from 'vue';
import VueApollo from 'vue-apollo';

import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import ReleaseStatsCard from 'ee/ci/analytics/group_ci_cd_analytics/components/group_release_stats_card.vue';
import groupReleaseStatsQuery from 'ee/ci/analytics/group_ci_cd_analytics/graphql/group_release_stats.query.graphql';
import { groupReleaseStatsQueryResponse } from './mock_data';

Vue.use(VueApollo);

describe('Release stats card', () => {
  let wrapper;
  let groupReleaseStatsHandler;

  const createComponent = ({ ...options } = {}) => {
    wrapper = shallowMountExtended(ReleaseStatsCard, {
      stubs: {
        GlCard,
      },
      apolloProvider: createMockApollo([[groupReleaseStatsQuery, groupReleaseStatsHandler]]),
      ...options,
    });
  };

  const findLoadingIndicators = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findStats = () => wrapper.findByTestId('stats-container');

  const expectLoadingIndicators = () => {
    expect(findLoadingIndicators()).toHaveLength(2);
  };

  const expectNoLoadingIndicators = () => {
    expect(findLoadingIndicators()).toHaveLength(0);
  };

  beforeEach(() => {
    groupReleaseStatsHandler = jest.fn();
  });

  describe('when the component is loading data', () => {
    beforeEach(() => {
      groupReleaseStatsHandler.mockReturnValueOnce(new Promise(() => {}));

      createComponent({
        provide: {
          groupFullPath: 'my-group',
        },
      });
    });

    it('renders loading indicators', () => {
      expectLoadingIndicators();
    });

    it('fetches with the group path', () => {
      expect(groupReleaseStatsHandler).toHaveBeenCalledWith({ fullPath: 'my-group' });
    });
  });

  describe('when the data has successfully loaded', () => {
    beforeEach(async () => {
      groupReleaseStatsHandler.mockReturnValueOnce(groupReleaseStatsQueryResponse);

      createComponent();
      await waitForPromises();
    });

    it('does not render loading indicators', () => {
      expectNoLoadingIndicators();
    });

    it('renders the card header', () => {
      const header = wrapper.find('header');

      expect(header.find('h1').text()).toMatchInterpolatedText('Releases');
      expect(header.find('h2').text()).toMatchInterpolatedText('All time');
    });

    it('renders the statistics', () => {
      expect(findStats().text()).toMatch(/2811\s*Releases\s*9%\s*Projects\s*with\s*releases/);
    });
  });

  describe('when the data is successfully returned, but the stats are all 0', () => {
    beforeEach(async () => {
      const responseWithZeros = merge({}, groupReleaseStatsQueryResponse, {
        data: {
          group: {
            stats: {
              releaseStats: {
                releasesCount: 0,
                releasesPercentage: 0,
              },
            },
          },
        },
      });

      groupReleaseStatsHandler.mockResolvedValueOnce(responseWithZeros);

      createComponent();
      await waitForPromises();
    });

    it('renders the statistics', () => {
      expect(findStats().text()).toMatch(/0\s*Releases\s*0%\s*Projects\s*with\s*releases/);
    });
  });

  describe('when an error occurs while loading data', () => {
    beforeEach(async () => {
      groupReleaseStatsHandler.mockRejectedValueOnce(new Error('network error'));

      createComponent();
      await waitForPromises();
    });

    it('does not render loading indicators', () => {
      expectNoLoadingIndicators();
    });

    it('renders questions marks in place of the numbers', () => {
      expect(findStats().text()).toMatch(/-\s*Releases\s*-\s*Projects\s*with\s*releases/i);
    });
  });
});
