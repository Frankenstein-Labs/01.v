import { GlButton, GlSkeletonLoader, GlProgressBar } from '@gitlab/ui';
import { nextTick } from 'vue';
import { numberToHumanSize } from '~/lib/utils/number_utils';
import ProjectLimitsExcessStorageBreakdownCard from 'ee/usage_quotas/storage/namespace/components/project_limits_excess_storage_breakdown_card.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { defaultNamespaceProvideValues } from '../../mock_data';

describe('ProjectLimitsExcessStorageBreakdownCard', () => {
  /** @type { import('helpers/vue_test_utils_helper').ExtendedWrapper } */
  let wrapper;

  const defaultProps = {
    purchasedStorage: 0,
    loading: false,
    limitedAccessModeEnabled: false,
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(ProjectLimitsExcessStorageBreakdownCard, {
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

  const findCardTitle = () => wrapper.findByTestId('purchased-storage-card-title');
  const findPercentageUsedSubtitle = () =>
    wrapper.findByTestId('purchased-storage-percentage-used');
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findGlButton = () => wrapper.findComponent(GlButton);
  const findProgressBar = () => wrapper.findComponent(GlProgressBar);

  describe('Buy storage button', () => {
    beforeEach(async () => {
      createComponent();

      findGlButton().vm.$emit('click');
      await nextTick();
    });

    it('renders purchase link with the correct attributes', () => {
      expect(findGlButton().attributes()).toMatchObject({
        href: 'some-fancy-url?ref_source=group_usage_quotas_page',
        target: '_blank',
      });
    });

    it('does not render buy storage button if subjectToHighLimit is true', () => {
      createComponent({
        provide: { subjectToHighLimit: true },
      });

      expect(findGlButton().exists()).toBe(false);
    });
  });

  describe('when limitedAccessModeEnabled prop is true', () => {
    beforeEach(async () => {
      createComponent({
        props: { limitedAccessModeEnabled: true },
      });

      findGlButton().vm.$emit('click');
      await nextTick();
    });

    it('renders purchase button without purchase link', () => {
      expect(findGlButton().attributes('href')).toBeUndefined();
    });
  });

  describe('skeleton loader', () => {
    it('renders skeleton loader when loading prop is true', () => {
      createComponent({ props: { loading: true } });
      expect(findSkeletonLoader().exists()).toBe(true);
    });

    it('does not render skeleton loader when loading prop is false', () => {
      createComponent({ props: { loading: false } });
      expect(findSkeletonLoader().exists()).toBe(false);
    });
  });

  it('renders the card subtitle related to the storage included', () => {
    createComponent();
    expect(wrapper.text()).toContain(
      numberToHumanSize(defaultNamespaceProvideValues.perProjectStorageLimit, 1),
    );
    expect(wrapper.text()).toContain('Storage per project included in Free subscription');
  });

  describe('card title', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the card title', () => {
      expect(findCardTitle().text()).toBe('Excess storage usage');
    });

    it('renders the help link with the proper attributes', () => {
      expect(findCardTitle().findComponent(HelpPageLink).props()).toMatchObject({
        anchor: 'view-storage',
        href: 'user/storage_usage_quotas',
      });
      expect(findCardTitle().findComponent(HelpPageLink).attributes('aria-label')).toBe(
        'Learn more about usage quotas.',
      );
    });
  });

  describe('numbers and percentages in the UI', () => {
    it('does not render the storage units if value is 0', () => {
      createComponent({
        props: { purchasedStorage: 0 },
        provide: { totalRepositorySizeExcess: 0 },
      });

      const componentText = wrapper.text().replace(/[\s\n]+/g, ' ');

      expect(componentText).toContain('0 / 0');
    });

    describe.each`
      excessStorage | purchasedStorage
      ${10}         | ${0}
      ${0}          | ${10}
    `(
      'Percentage info when excessStorage: $excessStorage, purchasedStorage: $purchasedStorage',
      ({ excessStorage, purchasedStorage }) => {
        beforeEach(() => {
          createComponent({
            props: { purchasedStorage },
            provide: { totalRepositorySizeExcess: excessStorage },
          });
        });

        it('does not render percentage progress bar', () => {
          expect(findProgressBar().exists()).toBe(false);
        });

        it('does not render percentage used subtitle', () => {
          expect(findPercentageUsedSubtitle().exists()).toBe(false);
        });
      },
    );

    describe.each`
      excessStorage | purchasedStorage | percentageUsage
      ${3}          | ${10}            | ${30}
      ${-1}         | ${10}            | ${0}
      ${10}         | ${3}             | ${100}
      ${10}         | ${-1}            | ${0}
    `(
      'UI behavior when excessStorage: $excessStorage, purchasedStorage: $purchasedStorage',
      ({ excessStorage, purchasedStorage, percentageUsage }) => {
        beforeEach(() => {
          createComponent({
            props: { purchasedStorage },
            provide: { totalRepositorySizeExcess: excessStorage },
          });
        });

        it('renders the used and total storage block', () => {
          const componentText = wrapper.text().replace(/[\s\n]+/g, ' ');

          expect(componentText).toContain(
            ` ${numberToHumanSize(excessStorage)} / ${numberToHumanSize(purchasedStorage)}`,
          );
        });

        it(`renders the progress bar as ${percentageUsage}`, () => {
          expect(findProgressBar().attributes('value')).toBe(String(percentageUsage));
        });

        it(`renders the percentage used subtitle with ${percentageUsage}`, () => {
          expect(findPercentageUsedSubtitle().text()).toContain(String(percentageUsage));
        });
      },
    );
  });
});
