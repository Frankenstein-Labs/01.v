import { GlSprintf, GlBadge, GlCard, GlButton, GlPopover } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GeoReplicableItemVerificationInfo from 'ee/geo_replicable_item/components/geo_replicable_item_verification_info.vue';
import { VERIFICATION_STATUS_STATES } from 'ee/geo_shared//constants';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { MOCK_REPLICABLE_WITH_VERIFICATION } from '../mock_data';

describe('GeoReplicableItemVerificationInfo', () => {
  let wrapper;

  const defaultProps = {
    replicableItem: MOCK_REPLICABLE_WITH_VERIFICATION,
  };

  const createComponent = ({ props = {} } = {}) => {
    const propsData = {
      ...defaultProps,
      ...props,
    };

    wrapper = shallowMountExtended(GeoReplicableItemVerificationInfo, {
      propsData,
      stubs: {
        GlSprintf,
        GlCard,
      },
    });
  };

  const findHelpIcon = () => wrapper.findComponent(HelpIcon);
  const findGlPopover = () => wrapper.findComponent(GlPopover);
  const findHelpPageLink = () => findGlPopover().findComponent(HelpPageLink);
  const findGlBadge = () => wrapper.findComponent(GlBadge);
  const findReverifyButton = () => wrapper.findComponent(GlButton);
  const findRetryAt = () => wrapper.findComponentByTestId('verification-retry-at-time-ago');
  const findVerificationStartedAt = () =>
    wrapper.findComponentByTestId('verification-started-at-time-ago');
  const findLastVerifiedAt = () => wrapper.findComponentByTestId('last-verified-at-time-ago');
  const findLocalVerificationChecksum = () => wrapper.findByTestId('local-verification-checksum');
  const findExpectedVerificationChecksum = () =>
    wrapper.findByTestId('expected-verification-checksum');
  const findTroubleshootingLink = () =>
    wrapper.findComponentByTestId('verification-failure-troubleshooting-link');

  describe('card header', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders help icon', () => {
      expect(findHelpIcon().attributes('id')).toBe('verification-information-help-icon');
    });

    it('renders popover', () => {
      expect(findGlPopover().props('target')).toBe('verification-information-help-icon');
      expect(findGlPopover().text()).toContain(
        'Shows the current verification status between the Primary and Secondary Geo site for this registry and whether it has encountered any issues during the verification process.',
      );
    });

    it('renders help page link in popover', () => {
      expect(findHelpPageLink().attributes('href')).toBe(
        'administration/geo/disaster_recovery/background_verification',
      );
    });

    it('renders the reverify button in the header', () => {
      expect(findReverifyButton().exists()).toBe(true);
    });

    it('emits reverify event when reverify button is clicked', async () => {
      findReverifyButton().vm.$emit('click');
      await nextTick();

      expect(wrapper.emitted('reverify')).toHaveLength(1);
    });
  });

  describe.each`
    verificationState | badge
    ${'PENDING'}      | ${VERIFICATION_STATUS_STATES.PENDING}
    ${'STARTED'}      | ${VERIFICATION_STATUS_STATES.STARTED}
    ${'SUCCEEDED'}    | ${VERIFICATION_STATUS_STATES.SUCCEEDED}
    ${'FAILED'}       | ${VERIFICATION_STATUS_STATES.FAILED}
    ${'DISABLED'}     | ${VERIFICATION_STATUS_STATES.DISABLED}
    ${'asdf'}         | ${VERIFICATION_STATUS_STATES.UNKNOWN}
    ${null}           | ${VERIFICATION_STATUS_STATES.UNKNOWN}
  `('when verification status is $verificationState', ({ verificationState, badge }) => {
    beforeEach(() => {
      createComponent({
        props: { replicableItem: { ...MOCK_REPLICABLE_WITH_VERIFICATION, verificationState } },
      });
    });

    it('renders the correct badge variant', () => {
      expect(findGlBadge().text()).toBe(badge.title);
      expect(findGlBadge().props('variant')).toBe(badge.variant);
    });
  });

  describe('verification failures', () => {
    describe('when verificationState is FAILED', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              verificationState: 'FAILED',
              verificationFailure: 'Something is broken',
              verificationRetryCount: 2,
              verificationRetryAt: '2025-01-01',
            },
          },
        });
      });

      it('does render error text', () => {
        expect(wrapper.text()).toContain('Error: Something is broken');
      });

      it('renders verification retry text', () => {
        expect(wrapper.text()).toContain('Next verification retry: Retry #2 scheduled');
        expect(findRetryAt().props('time')).toBe('2025-01-01');
      });

      it('does render troubleshooting link', () => {
        expect(findTroubleshootingLink().props('href')).toBe(
          'administration/geo/replication/troubleshooting/synchronization_verification',
        );
      });
    });

    describe('when verificationState is not FAILED', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              verificationState: 'SUCCEEDED',
            },
          },
        });
      });

      it('does not render error text', () => {
        expect(wrapper.text()).not.toContain('Error:');
      });

      it('does not render sync retry text', () => {
        expect(wrapper.text()).not.toContain('Next verification retry:');
        expect(findRetryAt().exists()).toBe(false);
      });

      it('does not render troubleshooting link', () => {
        expect(findTroubleshootingLink().exists()).toBe(false);
      });
    });
  });

  describe('verification started at', () => {
    describe('when verificationState is PENDING', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              verificationState: 'PENDING',
              verificationStartedAt: '2025-02-01',
            },
          },
        });
      });

      it('renders verification started at text', () => {
        expect(wrapper.findByText('Verification started:').exists()).toBe(true);
        expect(findVerificationStartedAt().props('time')).toBe('2025-02-01');
      });
    });

    describe('when verificationState is STARTED', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              verificationState: 'STARTED',
              verificationStartedAt: '2025-02-01',
            },
          },
        });
      });

      it('renders verification started at text', () => {
        expect(wrapper.findByText('Verification started:').exists()).toBe(true);
        expect(findVerificationStartedAt().props('time')).toBe('2025-02-01');
      });
    });

    describe('when verificationState is not PENDING or STARTED', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              verificationState: 'SUCCEEDED',
            },
          },
        });
      });

      it('renders verification started at text', () => {
        expect(wrapper.findByText('Verification started:').exists()).toBe(false);
      });
    });
  });

  describe('last verified', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders with TimeAgo component', () => {
      expect(wrapper.findByText('Last verified:').exists()).toBe(true);
      expect(findLastVerifiedAt().props('time')).toBe(MOCK_REPLICABLE_WITH_VERIFICATION.verifiedAt);
    });
  });

  describe('verification checksum', () => {
    describe('with no mismatch checksum', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders verification checksum with clipboard button', () => {
        expect(findLocalVerificationChecksum().text()).toBe(
          `Checksum: ${MOCK_REPLICABLE_WITH_VERIFICATION.verificationChecksum}`,
        );
        expect(findLocalVerificationChecksum().findComponent(ClipboardButton).props('text')).toBe(
          String(MOCK_REPLICABLE_WITH_VERIFICATION.verificationChecksum),
        );
      });

      it('does not render mismatched expected verification checksum with clipboard button', () => {
        expect(findExpectedVerificationChecksum().exists()).toBe(false);
      });
    });

    describe('with mismatched checksum', () => {
      beforeEach(() => {
        createComponent({
          props: {
            replicableItem: {
              ...MOCK_REPLICABLE_WITH_VERIFICATION,
              checksumMismatch: true,
              verificationChecksumMismatched: 'df65f2a4ee76b6edc9db7022d7e0ff95db9a5931',
            },
          },
        });
      });

      it('renders verification checksum with clipboard button', () => {
        expect(findLocalVerificationChecksum().text()).toBe(
          `Checksum: ${MOCK_REPLICABLE_WITH_VERIFICATION.verificationChecksum}`,
        );
        expect(findLocalVerificationChecksum().findComponent(ClipboardButton).props('text')).toBe(
          String(MOCK_REPLICABLE_WITH_VERIFICATION.verificationChecksum),
        );
      });

      it('renders mismatched expected checksum with clipboard button', () => {
        expect(findExpectedVerificationChecksum().text()).toBe(
          'Expected checksum: df65f2a4ee76b6edc9db7022d7e0ff95db9a5931',
        );
        expect(
          findExpectedVerificationChecksum().findComponent(ClipboardButton).props('text'),
        ).toBe('df65f2a4ee76b6edc9db7022d7e0ff95db9a5931');
      });
    });
  });
});
