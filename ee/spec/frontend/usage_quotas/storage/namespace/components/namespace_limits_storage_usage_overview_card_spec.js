import { GlProgressBar } from '@gitlab/ui';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import { namespace } from 'jest/usage_quotas/storage/mock_data';
import NamespaceLimitsStorageUsageOverviewCard from 'ee/usage_quotas/storage/namespace/components/namespace_limits_storage_usage_overview_card.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { defaultNamespaceProvideValues } from '../../mock_data';

describe('NamespaceLimitsStorageUsageOverviewCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  const defaultProps = {
    purchasedStorage: 0,
    usedStorage: namespace.rootStorageStatistics.storageSize,
    loading: false,
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(NamespaceLimitsStorageUsageOverviewCard, {
      propsData: { ...defaultProps, ...props },
      provide: {
        ...defaultNamespaceProvideValues,
        ...provide,
      },
      stubs: {
        NumberToHumanSize,
      },
    });
  };

  const findCardTitle = () => wrapper.findByTestId('namespace-storage-card-title');
  const findPercentageRemaining = () =>
    wrapper.findByTestId('namespace-storage-percentage-remaining');
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findSkeletonLoaders = () => wrapper.findAll('.gl-animate-skeleton-loader');

  describe('card title', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the card title', () => {
      expect(findCardTitle().text()).toBe('Namespace storage used');
    });

    it('renders the help link with the proper attributes', () => {
      expect(findCardTitle().findComponent(HelpPageLink).props()).toMatchObject({
        href: 'user/storage_usage_quotas',
        anchor: 'view-storage',
      });
      expect(findCardTitle().findComponent(HelpPageLink).attributes('aria-label')).toBe(
        'Learn more about usage quotas.',
      );
    });
  });

  it('only renders usedStorage if totalStorage is 0', () => {
    const usedStorage = 1000;

    createComponent({
      props: { usedStorage },
      provide: {
        namespaceStorageLimit: 0,
      },
    });

    const componentText = wrapper.text().replace(/[\s\n]+/g, ' ');
    expect(componentText).toContain(numberToHumanSize(usedStorage));
    expect(componentText).not.toContain('/');
  });

  describe.each`
    usedStorage | totalStorage
    ${0}        | ${0}
    ${10}       | ${0}
  `(
    'UI behavior related to percentage usage when totalStorage: $totalStorage, usedStorage: $usedStorage',
    ({ totalStorage, usedStorage }) => {
      beforeEach(() => {
        createComponent({
          props: { usedStorage },
          provide: {
            namespaceStorageLimit: totalStorage,
          },
        });
      });

      it('does not render percentage progress bar', () => {
        expect(findProgressBar().exists()).toBe(false);
      });

      it('does not render percentage remaining block', () => {
        expect(findPercentageRemaining().exists()).toBe(false);
      });
    },
  );

  describe.each`
    usedStorage | totalStorage | percentageUsage | percentageRemaining
    ${3}        | ${10}        | ${30}           | ${70}
    ${-1}       | ${10}        | ${0}            | ${100}
    ${10}       | ${3}         | ${100}          | ${0}
    ${10}       | ${-1}        | ${0}            | ${100}
  `(
    'UI behavior when usedStorage: $usedStorage, totalStorage: $totalStorage',
    ({ usedStorage, totalStorage, percentageUsage, percentageRemaining }) => {
      beforeEach(() => {
        createComponent({
          props: { usedStorage },
          provide: {
            namespaceStorageLimit: totalStorage,
          },
        });
      });

      it('renders the used and total storage block', () => {
        const componentText = wrapper.text().replace(/[\s\n]+/g, ' ');

        expect(componentText).toContain(
          ` ${numberToHumanSize(usedStorage)} / ${numberToHumanSize(totalStorage)}`,
        );
      });

      it(`renders the progress bar as ${percentageUsage}`, () => {
        expect(findProgressBar().attributes('value')).toBe(String(percentageUsage));
      });

      it(`renders the percentage remaining as ${percentageRemaining}`, () => {
        expect(findPercentageRemaining().text()).toContain(String(percentageRemaining));
      });
    },
  );

  describe('when usedStorage is 0 and totalStorage is bigger than 0', () => {
    const totalStorage = 10;
    const usedStorage = 0;

    beforeEach(() => {
      createComponent({
        props: { usedStorage },
        provide: {
          namespaceStorageLimit: totalStorage,
        },
      });
    });

    it('renders the used and total storage block', () => {
      const componentText = wrapper.text().replace(/[\s\n]+/g, ' ');

      expect(componentText).toContain(` 0 / ${numberToHumanSize(totalStorage)}`);
    });

    it('renders the progress bar correctly', () => {
      expect(findProgressBar().attributes('value')).toBe('0');
    });

    it('renders the percentage remaining correctly', () => {
      expect(findPercentageRemaining().text()).toContain('100');
    });
  });

  describe('skeleton loader', () => {
    it('renders skeleton loader when loading prop is true', () => {
      createComponent({ props: { loading: true } });
      expect(findSkeletonLoaders().exists()).toBe(true);
    });

    it('does not render skeleton loader when loading prop is false', () => {
      createComponent({ props: { loading: false } });
      expect(findSkeletonLoaders().exists()).toBe(false);
    });
  });
});
