import { GlCard, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { AVAILABILITY_OPTIONS } from 'ee/ai/settings/constants';
import DuoAmazonQInfoCard from 'ee/ai/settings/components/duo_amazon_q_info_card.vue';
import DuoConfigurationSettingsRow from 'ee/ai/settings/components/duo_configuration_settings_row.vue';

describe('DuoAmazonQInfoCard', () => {
  let wrapper;

  const createComponent = ({
    duoAvailability = AVAILABILITY_OPTIONS.DEFAULT_ON,
    amazonQConfigurationPath = '/gitlab_duo/amazon_q/configuration',
    amazonQReady = false,
    amazonQAutoReviewEnabled = false,
  } = {}) => {
    wrapper = shallowMountExtended(DuoAmazonQInfoCard, {
      provide: {
        duoAvailability,
        amazonQConfigurationPath,
        amazonQReady,
        amazonQAutoReviewEnabled,
      },
    });
  };

  const findCard = () => wrapper.findAllComponents(GlCard);
  const findConfigurationButton = () => wrapper.findComponent(GlButton);
  const findDuoConfigurationRows = () => wrapper.findAllComponents(DuoConfigurationSettingsRow);
  const findDuoConfigurationRowTitlePropByRowIdx = (idx) =>
    findDuoConfigurationRows().at(idx).props('duoConfigurationSettingsRowTypeTitle');
  const findAvailabilityStatus = () => wrapper.find('p');

  describe('on component loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the GlCard component', () => {
      expect(findCard().exists()).toBe(true);
    });

    it('renders the title correctly', () => {
      expect(wrapper.find('h2').text()).toBe('GitLab Duo with Amazon Q');
    });

    it('renders the configuration button with correct href', () => {
      expect(findConfigurationButton().exists()).toBe(true);
      expect(findConfigurationButton().attributes('href')).toBe(
        '/gitlab_duo/amazon_q/configuration',
      );
      expect(findConfigurationButton().text()).toBe('View configuration');
    });
  });

  describe('availability status', () => {
    it.each([
      [AVAILABILITY_OPTIONS.DEFAULT_ON, 'On by default'],
      [AVAILABILITY_OPTIONS.DEFAULT_OFF, 'Off by default'],
      [AVAILABILITY_OPTIONS.NEVER_ON, 'Always off'],
    ])('displays correct status for %s', (status, expected) => {
      createComponent({ duoAvailability: status });
      expect(findAvailabilityStatus().text()).toBe(expected);
    });
  });

  describe('DuoConfigurationSettingsRow rendering', () => {
    it('renders both rows with correct titles and states', () => {
      createComponent({ amazonQReady: true, amazonQAutoReviewEnabled: true });

      expect(findDuoConfigurationRows()).toHaveLength(2);
      expect(findDuoConfigurationRowTitlePropByRowIdx(0)).toBe('Amazon Q Setup');
      expect(findDuoConfigurationRowTitlePropByRowIdx(1)).toBe('Automatic Code Reviews');
    });

    it('disables rows when the corresponding prop is false', () => {
      createComponent({ amazonQReady: false, amazonQAutoReviewEnabled: false });

      expect(findDuoConfigurationRows().at(0).props('configValue')).toBe(false);
      expect(findDuoConfigurationRows().at(1).props('configValue')).toBe(false);
    });

    it('enables rows when the corresponding prop is true', () => {
      createComponent({ amazonQReady: true, amazonQAutoReviewEnabled: true });

      expect(findDuoConfigurationRows().at(0).props('configValue')).toBe(true);
      expect(findDuoConfigurationRows().at(1).props('configValue')).toBe(true);
    });
  });
});
