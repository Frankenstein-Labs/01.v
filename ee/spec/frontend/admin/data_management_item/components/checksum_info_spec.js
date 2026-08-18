import { GlCard, GlSprintf, GlBadge, GlButton, GlPopover } from '@gitlab/ui';
import models from 'test_fixtures/api/admin/data_management/snippet_repositories.json';
import ChecksumInfo from 'ee/admin/data_management_item/components/checksum_info.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('ChecksumInfo', () => {
  let wrapper;

  const [rawModel] = models;
  const model = convertObjectPropsToCamelCase(rawModel, { deep: true });

  const defaultProps = { details: model.checksumInformation, checksumLoading: false };

  const createComponent = ({ props } = { props: {} }) => {
    wrapper = shallowMountExtended(ChecksumInfo, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlCard, GlSprintf },
    });
  };

  const findHeading = () => wrapper.find('h5');
  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findChecksumStatus = () => wrapper.findByTestId('checksum-status');
  const findChecksumFailure = () => wrapper.findByTestId('checksum-failure');
  const findChecksumRetry = () => wrapper.findByTestId('checksum-retry');
  const findChecksumLast = () => wrapper.findByTestId('checksum-last');
  const findChecksum = () => wrapper.findByTestId('checksum');
  const findChecksumButton = () => wrapper.findComponent(GlButton);
  const findHelpIcon = () => wrapper.findComponent(HelpIcon);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findHelpPageLink = () => findGlPopover().findComponent(HelpPageLink);
  const findTroubleshootingLink = () =>
    wrapper.findComponentByTestId('checksum-failure-troubleshooting-link');

  it('renders card header', () => {
    createComponent();

    expect(findHeading().text()).toContain('Checksum information');
  });

  describe('card help popover', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders help icon', () => {
      expect(findHelpIcon().attributes('id')).toBe('checksum-information-help-icon');
    });

    it('renders popover', () => {
      expect(findGlPopover().props('target')).toBe('checksum-information-help-icon');
      expect(findGlPopover().text()).toContain(
        "Verifies data integrity on the primary site by calculating a checksum of the model's data. This can later be used to ensure replicated data matches between primary and secondary Geo sites, helping detect corruption during replication.",
      );
    });

    it('renders help page link in popover', () => {
      expect(findHelpPageLink().attributes('href')).toBe(
        'administration/geo/disaster_recovery/background_verification',
      );
    });
  });

  describe('when status is known', () => {
    it('renders status badge with correct variant and title', () => {
      createComponent({
        props: { details: { ...model.checksumInformation, checksumState: 'succeeded' } },
      });

      expect(findChecksumStatus().text()).toContain('Status:');
      expect(findGlBadge().text()).toBe('Succeeded');
      expect(findGlBadge().props('variant')).toBe('success');
    });
  });

  describe('when status is unknown', () => {
    it('renders unknown status badge', () => {
      createComponent({
        props: { details: { ...model.checksumInformation, checksumState: null } },
      });

      expect(findChecksumStatus().text()).toContain('Status:');
      expect(findGlBadge().text()).toBe('Unknown');
      expect(findGlBadge().props('variant')).toBe('neutral');
    });
  });

  describe('when status have not failed', () => {
    beforeEach(() => {
      createComponent({
        props: { details: { ...model.checksumInformation, checksumFailure: null } },
      });
    });

    it('does not render checksum failure', () => {
      expect(findChecksumFailure().exists()).toBe(false);
    });

    it('does not render retry information', () => {
      expect(findChecksumRetry().exists()).toBe(false);
    });

    it('does not render troubleshooting link', () => {
      expect(findTroubleshootingLink().exists()).toBe(false);
    });
  });

  describe('when status failed', () => {
    beforeEach(() => {
      createComponent({
        props: {
          details: {
            ...model.checksumInformation,
            checksumFailure: 'Connection timeout',
            retryCount: 3,
            retryAt: '2024-01-01T00:00:00Z',
          },
        },
      });
    });

    it('renders checksum failure message', () => {
      expect(findChecksumFailure().text()).toBe('Error: Connection timeout');
    });

    it('renders retry count', () => {
      expect(findChecksumRetry().text()).toContain('Retry #3');
    });

    it('renders retry scheduled time', () => {
      expect(findChecksumRetry().text()).toContain('Next checksum retry:');
      expect(findChecksumRetry().findComponent(TimeAgo).props('time')).toBe('2024-01-01T00:00:00Z');
    });

    it('does render troubleshooting link', () => {
      expect(findTroubleshootingLink().props('href')).toBe(
        'administration/geo/replication/troubleshooting/synchronization_verification',
      );
    });
  });

  describe('when lastChecksum is defined', () => {
    it('renders last checksum time', () => {
      createComponent({
        props: {
          details: {
            ...model.checksumInformation,
            lastChecksum: '2024-01-01T00:00:00Z',
          },
        },
      });

      expect(findChecksumLast().text()).toContain('Last checksum:');
      expect(findChecksumLast().findComponent(TimeAgo).props('time')).toBe('2024-01-01T00:00:00Z');
    });
  });

  describe('when lastChecksum is not defined', () => {
    it('does not render last checksum time', () => {
      createComponent({
        props: { details: { ...model.checksumInformation, lastChecksum: null } },
      });

      expect(findChecksumLast().exists()).toBe(false);
    });
  });

  describe('when checksum is defined', () => {
    beforeEach(() => {
      createComponent({
        props: { details: { ...model.checksumInformation, checksum: 'abc123def456' } },
      });
    });

    it('renders checksum value', () => {
      expect(findChecksum().text()).toBe('Checksum: abc123def456');
    });

    it('renders clipboard button', () => {
      expect(findChecksum().findComponent(ClipboardButton).props()).toMatchObject({
        title: 'Copy',
        text: 'abc123def456',
      });
    });
  });

  describe('when checksum is not defined', () => {
    beforeEach(() => {
      createComponent({
        props: { details: { ...model.checksumInformation, checksum: null } },
      });
    });

    it('renders "Unknown" text', () => {
      expect(findChecksum().text()).toBe('Checksum: Unknown');
    });

    it('does not render clipboard button', () => {
      expect(findChecksum().findComponent(ClipboardButton).exists()).toBe(false);
    });
  });

  describe('when checksumLoading is false', () => {
    beforeEach(() => {
      createComponent({ props: { checksumLoading: false } });
    });

    it('renders checksum button with loading disabled', () => {
      expect(findChecksumButton().props('loading')).toBe(false);
    });

    describe('when checksum button is clicked', () => {
      it('emits `recalculate-checksum` event', () => {
        findChecksumButton().vm.$emit('click');

        expect(wrapper.emitted('recalculate-checksum')).toHaveLength(1);
      });
    });
  });

  describe('when checksumLoading is true', () => {
    it('renders checksum button with loading enabled', () => {
      createComponent({ props: { checksumLoading: true } });

      expect(findChecksumButton().props('loading')).toBe(true);
    });
  });
});
