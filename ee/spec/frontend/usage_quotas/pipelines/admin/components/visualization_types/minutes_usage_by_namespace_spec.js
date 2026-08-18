import { GlAvatar, GlTable } from '@gitlab/ui';
import MinutesUsageByNamespace from 'ee/usage_quotas/pipelines/admin/components/visualization_types/minutes_usage_by_namespace.vue';
import NoMinutesAlert from 'ee/usage_quotas/pipelines/admin/components/shared/no_minutes_alert.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { usageDataNamespaceAggregated } from '../../mock_data';

describe('MinutesUsageByNamespace', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findDuration = () => wrapper.findByTestId('runner-duration');
  const findComputeMinutes = () => wrapper.findByTestId('compute-minutes');
  const findNoMinutesAlertComponent = () => wrapper.findComponent(NoMinutesAlert);
  const findRunnerNamespaces = () => wrapper.findAllByTestId('runner-namespace');

  const createComponent = (props = {}) => {
    wrapper = mountExtended(MinutesUsageByNamespace, {
      propsData: {
        usageData: usageDataNamespaceAggregated,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('with usage data available', () => {
    it('renders the table', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('renders the namespace avatar', () => {
      expect(findAvatar().exists()).toBe(true);
      expect(findAvatar().props('src')).toBe(
        'https://secure.gravatar.com/avatar/258d8dc916db8cea2cafb6c3cd0cb0246efe061421dbd83ec3a350428cabda4f?s=80&d=identicon',
      );
    });

    it('renders hosted runner duration', () => {
      expect(findDuration().text()).toBe('200.33');
    });

    it('renders compute minutes', () => {
      expect(findComputeMinutes().text()).toBe('200.33');
    });

    it('renders "Deleted Namespace" for deleted namespaces for their name', () => {
      const missingNamespace = findRunnerNamespaces().at(2);

      expect(missingNamespace.text()).toBe('Deleted Namespace #34');
    });
  });

  describe('with no usage data', () => {
    beforeEach(() => {
      createComponent({
        usageData: [],
      });
    });

    it('renders an empty state', () => {
      expect(findNoMinutesAlertComponent().exists()).toBe(true);
    });
  });
});
