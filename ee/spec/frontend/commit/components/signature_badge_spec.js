import { GlBadge, GlLink, GlPopover } from '@gitlab/ui';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import SignatureBadge from '~/commit/components/signature_badge.vue';
import { statusConfig, verificationStatuses, signatureTypes } from 'ee_else_ce/commit/constants';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('Commit signature', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(SignatureBadge, {
      propsData: {
        signature: {
          ...props,
        },
        stubs: {
          GlBadge,
          GlLink,
          GlPopover: stubComponent(GlPopover, { template: RENDER_ALL_SLOTS_TEMPLATE }),
        },
      },
    });
  };

  const signatureBadge = () => wrapper.findComponent(GlBadge);
  const signaturePopover = () => wrapper.findComponent(GlPopover);
  const signatureDescription = () => wrapper.findByTestId('signature-description');

  describe.each`
    signatureType         | verificationStatus
    ${signatureTypes.SSH} | ${verificationStatuses.VERIFIED_CA}
  `(
    'For a specified `$signatureType` and `$verificationStatus` it renders component correctly',
    ({ signatureType, verificationStatus }) => {
      beforeEach(() => {
        createComponent({ __typename: signatureType, verificationStatus });
      });
      it('renders correct badge class', () => {
        expect(signatureBadge().props('variant')).toBe(statusConfig[verificationStatus].variant);
      });
      it('renders badge text', () => {
        expect(signatureBadge().text()).toBe(statusConfig[verificationStatus].label);
      });
      it('renders  popover header text', () => {
        expect(signaturePopover().text()).toMatch(statusConfig[verificationStatus].title);
      });
      it('renders signature description', () => {
        expect(signatureDescription().text()).toBe(statusConfig[verificationStatus].description);
      });
    },
  );
});
