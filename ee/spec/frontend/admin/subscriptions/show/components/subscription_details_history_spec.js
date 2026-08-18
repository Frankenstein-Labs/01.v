import { GlBadge } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import SubscriptionDetailsHistory from 'ee/admin/subscriptions/show/components/subscription_details_history.vue';
import { onlineCloudLicenseText } from 'ee/admin/subscriptions/show/constants';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { getLicenseTypeLabel } from 'ee/admin/subscriptions/show/utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import { license, subscriptionFutureHistory, subscriptionPastHistory } from '../mock_data';

const subscriptionList = [...subscriptionFutureHistory, ...subscriptionPastHistory];
const currentSubscriptionIndex = subscriptionFutureHistory.length;

describe('Subscription Details History', () => {
  let wrapper;

  const findTableRows = () => wrapper.findAllByTestId('subscription-history-row');
  const findCurrentRow = () => findTableRows().at(currentSubscriptionIndex);
  const cellFinder = (row) => (testId) => extendedWrapper(row).findByTestId(testId);
  const containsABadge = (row) => row.findComponent(GlBadge).exists();

  const createComponent = (props) => {
    wrapper = extendedWrapper(
      mount(SubscriptionDetailsHistory, {
        propsData: {
          currentSubscriptionId: license.ULTIMATE.id,
          subscriptionList,
          ...props,
        },
      }),
    );
  };

  describe('with data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('has a current subscription row', () => {
      expect(findCurrentRow().exists()).toBe(true);
    });

    it('has the correct number of subscription rows', () => {
      expect(findTableRows()).toHaveLength(subscriptionList.length);
    });

    it('has the correct license type', () => {
      expect(findCurrentRow().text()).toContain(onlineCloudLicenseText);
      expect(findTableRows().at(4).text()).toContain('Legacy license');
    });

    it('has a badge for the license type', () => {
      expect(findTableRows().wrappers.every(containsABadge)).toBe(true);
    });

    it('highlights the current subscription row', () => {
      // The current subscription row should have the highlighted background class
      const currentRowCells = findCurrentRow().findAll('td');
      expect(
        currentRowCells.wrappers.some(
          (cell) =>
            cell.classes().includes('gl-bg-blue-50') || cell.classes().includes('!gl-bg-blue-50'),
        ),
      ).toBe(true);
    });

    it('does not highlight the other subscription row', () => {
      const otherRowCells = findTableRows().at(0).findAll('td');
      expect(
        otherRowCells.wrappers.some(
          (cell) =>
            cell.classes().includes('gl-bg-blue-50') || cell.classes().includes('!gl-bg-blue-50'),
        ),
      ).toBe(false);
    });

    describe.each(Object.entries(subscriptionList))('cell data index=%#', (index, subscription) => {
      let findCellByTestid;

      beforeEach(() => {
        createComponent();
        findCellByTestid = cellFinder(findTableRows().at(index));
      });

      it.each`
        testId                      | key
        ${'starts-at'}              | ${'startsAt'}
        ${'expires-at'}             | ${'expiresAt'}
        ${'users-in-license-count'} | ${'usersInLicenseCount'}
      `('displays the correct value for the $testId cell', ({ testId, key }) => {
        const cellTestId = `subscription-cell-${testId}`;
        const value = subscription[key] || '-';
        expect(findCellByTestid(cellTestId).text()).toBe(value);
      });

      it('displays the name field with company and email', () => {
        const cellTestId = 'subscription-cell-name';
        const text = findCellByTestid(cellTestId).text();
        expect(text).toContain(subscription.name);
        expect(text).toContain(`(${subscription.company})`);
        expect(text).toContain(subscription.email);
      });

      it('displays the correct value for the type cell', () => {
        const cellTestId = `subscription-cell-type`;
        expect(findCellByTestid(cellTestId).text()).toBe(getLicenseTypeLabel(subscription.type));
      });

      it('displays the correct value for the plan cell', () => {
        const cellTestId = `subscription-cell-plan`;
        expect(findCellByTestid(cellTestId).text()).toBe(
          capitalizeFirstCharacter(subscription.plan),
        );
      });

      it('displays the correct value for the activated-at cell', () => {
        const cellTestId = `subscription-cell-activated-at`;
        const value = subscription.activatedAt || '-';
        expect(findCellByTestid(cellTestId).text()).toBe(value);
      });
    });
  });

  describe('plan cell formatting', () => {
    it.each`
      hasGitlabCreditsAddOn | expectedText
      ${true}               | ${'Free with GitLab Credits'}
      ${false}              | ${'Free'}
    `(
      'shows "$expectedText" when hasGitlabCreditsAddOn is $hasGitlabCreditsAddOn',
      ({ hasGitlabCreditsAddOn, expectedText }) => {
        createComponent({
          subscriptionList: [{ ...subscriptionPastHistory[1], hasGitlabCreditsAddOn }],
        });

        expect(wrapper.findByTestId('subscription-cell-plan').text()).toBe(expectedText);
      },
    );
  });

  describe('with no data', () => {
    beforeEach(() => {
      createComponent({
        subscriptionList: [],
      });
    });

    it('has the correct number of rows', () => {
      expect(findTableRows()).toHaveLength(0);
    });
  });
});
