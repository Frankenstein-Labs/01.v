import { GlModal, GlLink } from '@gitlab/ui';
import { createWrapper } from '@vue/test-utils';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependenciesLicenseLinks from 'ee/dependencies/components/dependency_license_links.vue';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';

describe('DependencyLicenseLinks component', () => {
  // data helpers
  const createLicenses = (n) => [...Array(n).keys()].map((i) => ({ name: `license ${i + 1}` }));
  const addUrls = (licenses, numLicensesWithUrls = Infinity) =>
    licenses.map((ls, i) => {
      if (i >= numLicensesWithUrls) return ls;
      return {
        ...ls,
        url: `license ${i + 1}`,
      };
    });
  const addPolicyViolations = (licenses, numLicensesWithViolations = 0) =>
    licenses.map((ls, i) => {
      if (i >= numLicensesWithViolations) return ls;
      return {
        ...ls,
        policyViolations: [{ id: i + 1 }],
      };
    });

  // wrapper / factory
  let wrapper;
  const factory = ({
    numLicenses = 0,
    numLicensesWithUrl = 0,
    numLicensesWithPolicyViolations = 0,
    unknownLicenseName = null,
    title = 'test-dependency',
    provide = {},
  } = {}) => {
    const licenses = [];

    if (unknownLicenseName) {
      licenses.push({
        name: unknownLicenseName,
        spdxIdentifier: 'unknown',
      });
    }

    if (numLicenses > 0) {
      const baseLicenses = createLicenses(numLicenses);
      const licensesWithUrls = addUrls(baseLicenses, numLicensesWithUrl);
      const licensesWithViolations = addPolicyViolations(
        licensesWithUrls,
        numLicensesWithPolicyViolations,
      );
      licenses.push(...licensesWithViolations);
    }

    wrapper = shallowMountExtended(DependenciesLicenseLinks, {
      propsData: { licenses, title },
      provide,
    });
  };

  const factoryWithSpecificLicenses = (propsData = {}) => {
    wrapper = shallowMountExtended(DependenciesLicenseLinks, { propsData });
  };

  // query helpers
  const findLicensesList = () => wrapper.findByTestId('license-list');
  const findLicenseListItems = () => wrapper.findAllByTestId('license-list-item');
  const findModal = () => wrapper.findByTestId('modal');
  const findModalItem = () => wrapper.findAllByTestId('modal-item');
  const findLicenseBadge = () => wrapper.findByTestId('license-badge');
  const findBadgeTooltip = () =>
    findLicenseBadge().exists() ? findLicenseBadge().attributes('title') : null;
  const findModalItemTexts = () =>
    wrapper.findAllByTestId('modal-item').wrappers.map((item) => item.text());
  const findPolicyViolationBadge = () => wrapper.findByTestId('policy-violation-badge');

  it('intersperses the list of licenses correctly', () => {
    factory();

    const intersperseInstance = findLicensesList();

    expect(intersperseInstance.exists()).toBe(true);
    expect(intersperseInstance.attributes('lastseparator')).toBe(' and ');
  });

  it.each([1, 2])('limits the number of visible licenses to 1', (numLicenses) => {
    factory({ numLicenses });

    expect(findLicenseListItems()).toHaveLength(1);
  });

  it.each`
    numLicenses | numLicensesWithUrl | expectedNumVisibleLinks | expectedNumModalLinks
    ${0}        | ${0}               | ${0}                    | ${0}
    ${1}        | ${1}               | ${1}                    | ${0}
    ${2}        | ${1}               | ${1}                    | ${1}
    ${2}        | ${2}               | ${1}                    | ${2}
    ${3}        | ${2}               | ${1}                    | ${2}
  `(
    'contains the correct number of links given $numLicenses licenses where $numLicensesWithUrl contain a url',
    ({ numLicenses, numLicensesWithUrl, expectedNumVisibleLinks, expectedNumModalLinks }) => {
      factory({ numLicenses, numLicensesWithUrl });

      expect(findLicensesList().findAllComponents(GlLink)).toHaveLength(expectedNumVisibleLinks);
      expect(findModal().findAllComponents(GlLink)).toHaveLength(expectedNumModalLinks);
    },
  );

  it('sets all links to open in new windows/tabs', () => {
    factory({ numLicenses: 8, numLicensesWithUrl: 8 });

    const links = wrapper.findAllComponents(GlLink);

    links.wrappers.forEach((link) => {
      expect(link.attributes('target')).toBe('_blank');
    });
  });

  it.each`
    numLicenses | expectedNumExceedingLicenses
    ${0}        | ${0}
    ${1}        | ${0}
    ${2}        | ${1}
    ${3}        | ${2}
  `(
    'shows $expectedNumExceedingLicenses licenses that are included in the modal when there are $numLicenses licenses',
    async ({ numLicenses, expectedNumExceedingLicenses }) => {
      factory({ numLicenses });

      await nextTick();

      const badge = findLicenseBadge();

      if (expectedNumExceedingLicenses === 0) {
        expect(badge.exists()).toBe(false);
      } else {
        expect(badge.exists()).toBe(true);
        expect(badge.text()).toBe(`+${expectedNumExceedingLicenses} more`);
      }
    },
  );

  it.each`
    numLicenses | expectedNumModals
    ${0}        | ${0}
    ${1}        | ${0}
    ${2}        | ${1}
  `(
    'contains $expectedNumModals modal when $numLicenses licenses are given',
    ({ numLicenses, expectedNumModals }) => {
      factory({ numLicenses, expectedNumModals });

      expect(wrapper.findAllComponents(GlModal)).toHaveLength(expectedNumModals);
    },
  );

  it.each`
    unknownLicenseName | expectedTooltipText
    ${'unknown'}       | ${'This package also includes a license which was not identified by the scanner.'}
    ${'1 unknown'}     | ${'This package also includes a license which was not identified by the scanner.'}
    ${'2 unknown'}     | ${'This package also includes 2 licenses which were not identified by the scanner.'}
  `(
    'displays the correct tooltip text for an unknown license named "$unknownLicenseName"',
    async ({ unknownLicenseName, expectedTooltipText }) => {
      factory({ numLicenses: 5, unknownLicenseName });

      await nextTick();

      expect(findLicenseBadge().exists()).toBe(true);
      expect(findBadgeTooltip()).toBe(expectedTooltipText);
    },
  );

  it.each`
    numLicenses | unknownLicenseName | expectedBadgeText
    ${0}        | ${null}            | ${null}
    ${1}        | ${'unknown'}       | ${'+1 more'}
    ${1}        | ${'1 unknown'}     | ${'+1 more'}
    ${2}        | ${'2 unknown'}     | ${'+3 more'}
  `(
    'correctly calculates total count for $numLicenses known and extracted count from "$unknownLicenseName"',
    async ({ numLicenses, unknownLicenseName, expectedBadgeText }) => {
      factory({ numLicenses, unknownLicenseName });

      await nextTick();

      const badge = findLicenseBadge();

      if (expectedBadgeText === null) {
        expect(badge.exists()).toBe(false);
      } else {
        expect(badge.exists()).toBe(true);
        expect(badge.text()).toBe(expectedBadgeText);
      }
    },
  );

  it('ensures unknown licenses are always listed last', async () => {
    const licenses = [
      { name: 'MIT' },
      { name: '3 unknown', spdxIdentifier: 'unknown' },
      { name: 'GPL' },
      { name: 'Apache' },
    ];

    factoryWithSpecificLicenses({ licenses, title: 'test-dependency' });
    await nextTick();
    const licenseTexts = findModalItemTexts();

    expect(licenseTexts).toEqual(['Apache', 'GPL', 'MIT', '3 unknown']);
  });

  it('opens the modal when the trigger gets clicked', () => {
    factory({ numLicenses: 2 });
    const modalId = wrapper.findComponent(GlModal).props('modalId');
    const modalTrigger = findLicenseBadge();

    const rootWrapper = createWrapper(wrapper.vm.$root);

    modalTrigger.trigger('click');
    expect(rootWrapper.emitted(BV_SHOW_MODAL)[0]).toContain(modalId);
  });

  it('assigns a unique modal-id to each of its instances', () => {
    const numLicenses = 4;
    const usedModalIds = [];

    while (usedModalIds.length < 10) {
      factory({ numLicenses });
      const modalId = wrapper.findComponent(GlModal).props('modalId');

      expect(usedModalIds).not.toContain(modalId);
      usedModalIds.push(modalId);
    }
  });

  it('uses the title as the modal-title', () => {
    const title = 'test-dependency';
    factory({ numLicenses: 2, title });

    expect(wrapper.findComponent(GlModal).attributes('title')).toEqual(title);
  });

  it('assigns the correct action button text to the modal', () => {
    factory({ numLicenses: 2 });

    expect(wrapper.findComponent(GlModal).attributes('ok-title')).toEqual('Close');
  });

  it.each`
    numLicenses | expectedLicensesInModal
    ${1}        | ${0}
    ${2}        | ${2}
    ${3}        | ${3}
  `(
    'contains the correct modal content for $numLicenses licenses',
    ({ numLicenses, expectedLicensesInModal }) => {
      factory({ numLicenses });

      expect(findModalItem()).toHaveLength(expectedLicensesInModal);
    },
  );

  describe('security policy dismissal badge', () => {
    it('does not show the badge if none of the licenses have violated a security policy', () => {
      factory({ numLicenses: 1 });

      expect(findPolicyViolationBadge().exists()).toBe(false);
    });

    it('shows the badge if licenses have violated a security policy', () => {
      factory({
        numLicenses: 1,
        numLicensesWithPolicyViolations: 1,
      });

      expect(findPolicyViolationBadge().exists()).toBe(true);
    });
  });
});
